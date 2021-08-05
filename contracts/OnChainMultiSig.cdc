import Crypto

pub contract OnChainMultiSig {
    
    pub event NewPayloadAdded(resourceId: UInt64, txIndex: UInt64);
    pub event NewPayloadSigAdded(resourceId: UInt64, txIndex: UInt64);

    /// Argument for payload
    pub struct PayloadArg {
        pub let type: Type;
        pub let value: AnyStruct;
        
        init(t: Type, v: AnyStruct) {
            self.type = t;
            self.value = v
        }
    }

    pub struct PayloadDetails {
        pub var method: String;
        pub var args: [PayloadArg];
        
        init(method: String, args: [PayloadArg]) {
            self.method = method;
            self.args = args;
        }

    }

    pub struct PubKeyAttr{
        pub let sigAlgo: UInt8;
        pub let weight: UFix64
        
        init(sa: UInt8, w: UFix64) {
            self.sigAlgo = sa;
            self.weight = w;
        }
    }
    
    pub struct PayloadSigDetails {
        pub var keyListSignatures: [Crypto.KeyListSignature];
        pub var pubKeys: [String];

        init(keyListSignatures: [Crypto.KeyListSignature], pubKeys: [String]){
            self.keyListSignatures = keyListSignatures;
            self.pubKeys = pubKeys 
        }
    }

    pub resource interface PublicSigner {
        // the first [UInt8] in the signable data will be the method
        // follow by the args if args are not resources
        pub fun UUID(): UInt64; 
        pub var signatureStore: SignatureStore;
        pub fun addNewPayload(payload: PayloadDetails, publicKey: String, sig: [UInt8]);
        pub fun addPayloadSignature (txIndex: UInt64, publicKey: String, sig: [UInt8]);
        pub fun executeTx(txIndex: UInt64): @AnyResource?;
    }
    
    pub struct interface SignatureManager {
        pub fun getSignableData(payload: PayloadDetails): [UInt8];
        pub fun addNewPayload (resourceId: UInt64, payload: PayloadDetails, publicKey: String, sig: [UInt8]): SignatureStore;
        pub fun addPayloadSignature (resourceId: UInt64, txIndex: UInt64, publicKey: String, sig: [UInt8]): SignatureStore;
        pub fun readyForExecution(txIndex: UInt64): PayloadDetails?;
    }

    pub struct SignatureStore {
        // Transaction index
        pub(set) var txIndex: UInt64;

        // Signers and their weights
        // String in hex to be decoded as [UInt8], without "0x" prefix
        pub let keyList: {String: PubKeyAttr};

        // map of an assigned index and the payload
        // payload in this case is the script and argument
        pub var payloads: {UInt64: PayloadDetails}

        pub var payloadSigs: {UInt64: PayloadSigDetails}

        init(publicKeys: [String], pubKeyAttrs: [PubKeyAttr]){
            assert( publicKeys.length == pubKeyAttrs.length, message: "pubkeys must have associated attributes")
            self.payloads = {};
            self.payloadSigs = {};
            self.keyList = {};
            self.txIndex = 0;
            
            var i: Int = 0;
            while (i < publicKeys.length){
                self.keyList.insert(key: publicKeys[i], pubKeyAttrs[i]);
                i = i + 1;
            }
        }
    }

    pub struct Manager: SignatureManager {
        
        pub var signatureStore: SignatureStore;

        pub fun getSignableData(payload: PayloadDetails): [UInt8] {
            var s = payload.method.utf8;
            for a in payload.args {
                var b: [UInt8] = [];
                switch a.type {
                    case Type<String>():
                        let temp = a.value as? String;
                        b = temp!.utf8; 
                    case Type<UInt64>():
                        let temp = a.value as? UInt64;
                        b = temp!.toBigEndianBytes(); 
                    case Type<UFix64>():
                        let temp = a.value as? UFix64;
                        b = temp!.toBigEndianBytes(); 
                    case Type<Address>():
                        let temp = a.value as? Address;
                        b = temp!.toBytes(); 
                    default:
                        panic ("Payload arg type not supported")
                }
                s = s.concat(b);
            }
            return s; 
        }
        
        // Currently not supporting MultiSig
        pub fun configureKeys (pks: [String], kws: [UFix64]): SignatureStore {
            var i: Int =  0;
            while (i < pks.length) {
                let a = PubKeyAttr(sa: 1, w: kws[i])
                self.signatureStore.keyList.insert(key: pks[i], a)
                i = i + 1;
            }

            return self.signatureStore
        }

        // Currently not supporting MultiSig
        pub fun removeKeys (pks: [String], kws: [UFix64]): SignatureStore {
            // TODO
            return self.signatureStore
        }
        
        pub fun addNewPayload (resourceId: UInt64, payload: PayloadDetails, publicKey: String, sig: [UInt8]): SignatureStore {
            // check if the payloadSig is signed by one of the account's keys, preventing others from adding to storage
            if (self.verifyIsOneOfSigners(payload: payload, txIndex: nil, pk: publicKey, sig: sig) == false) {
                panic ("invalid signer")
            }

            let txIndex = self.signatureStore.txIndex.saturatingAdd(1);
            self.signatureStore.txIndex = txIndex;
            assert(!self.signatureStore.payloads.containsKey(txIndex), message: "Payload index already exist");

            self.signatureStore.payloads.insert(key: txIndex, payload);

            // The keyIndex is also 0 for the first key
            let payloadSigDetails = 
                PayloadSigDetails(
                    keyListSignatures: [Crypto.KeyListSignature( keyIndex: 0, signature: sig)],
                    pubKeys: [publicKey]
                )
            
            self.signatureStore.payloadSigs.insert(
                key: txIndex, 
                payloadSigDetails 
            )
            
            emit NewPayloadAdded(resourceId: resourceId, txIndex: txIndex)
            return self.signatureStore
        }

        pub fun addPayloadSignature (resourceId: UInt64, txIndex: UInt64, publicKey: String, sig: [UInt8]): SignatureStore {
            assert(self.signatureStore.payloads.containsKey(txIndex), message: "Payload has not been added");

            // check if the the signer is the accounting owning this signer by using data as the one in payloads
            if (self.verifyIsOneOfSigners(payload: nil, txIndex: txIndex, pk: publicKey, sig: sig) == false) {
                panic ("invalid signer")
            }

            let currentIndex = self.signatureStore.payloadSigs[txIndex]!.keyListSignatures.length
            self.signatureStore.payloadSigs[txIndex]!.keyListSignatures.append(Crypto.KeyListSignature(keyIndex: currentIndex, signature: sig));
            self.signatureStore.payloadSigs[txIndex]!.pubKeys.append(publicKey);

            // if weight of all the signatures above threshold, call executeTransaction
            emit NewPayloadSigAdded(resourceId: resourceId, txIndex: txIndex)
            return self.signatureStore
        }

        pub fun readyForExecution(txIndex: UInt64): PayloadDetails? {
            assert(self.signatureStore.payloads.containsKey(txIndex), message: "No payload for such index");
            // 1. returns the signed weights of the particular transaction by Transaction index
            // 2. if not enough weight etc, return nil
            let pd = self.signatureStore.payloads.remove(key: txIndex)!;
            return pd;
        }
        
        pub fun verifyIsOneOfSigners (payload: PayloadDetails?, txIndex: UInt64?, pk: String, sig: [UInt8]): Bool {
            assert(payload != nil || txIndex != nil, message: "cannot verify signature without payload or txIndex");
            assert(!(payload != nil && txIndex != nil), message: "cannot verify signature without payload or txIndex");
            assert(self.signatureStore.keyList.containsKey(pk), message: "no signer stored for multisig")
            
            let pk = PublicKey(
                publicKey: pk.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm(rawValue: self.signatureStore.keyList[pk]!.sigAlgo) ?? panic ("invalid signature algo")
            )

            var payloadInBytes: [UInt8] = []

            if (payload != nil) {
                payloadInBytes = self.getSignableData(payload: payload!);
            } else {
                let p = self.signatureStore.payloads[txIndex!];
                payloadInBytes = self.getSignableData(payload: p!);
            }
            
            return pk.verify(
                signature: sig,
                signedData: payloadInBytes,
                domainSeparationTag: "FLOW-V0.0-user",
                hashAlgorithm: HashAlgorithm.SHA3_256
            )
            
        }
        
        
        init(sigStore: SignatureStore) {
            self.signatureStore = sigStore;
        }
            
    }
}