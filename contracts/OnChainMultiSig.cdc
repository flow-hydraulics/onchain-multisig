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

    pub struct KeyListElement {
        // String in hex to be decoded as [UInt8]
        pub let publicKey: String;
        pub let sigAlgo: UInt8;
        pub let weight: UFix64
        
        init(pk: String, sa: UInt8, w: UFix64) {
            self.publicKey = pk;
            self.sigAlgo = sa;
            self.weight = w;
        }
    }

    pub resource interface PublicSigner {
        // the first [UInt8] in the signable data will be the method
        // follow by the args if args are not resources
        pub fun UUID(): UInt64; 
        pub var signatureStore: SignatureStore;
        pub fun addNewPayload(payload: PayloadDetails, keyListIndex: Int, sig: [UInt8]);
        pub fun addPayloadSignature (txIndex: UInt64, keyListIndex: Int, sig: [UInt8]);
        pub fun executeTx(txIndex: UInt64): @AnyResource?;
    }
    
    pub struct interface SignatureManager {
        pub fun getSignableData(payload: PayloadDetails): [UInt8];
        pub fun addNewPayload (resourceId: UInt64, payload: PayloadDetails, keyListIndex: Int, sig: [UInt8]): SignatureStore;
        pub fun addPayloadSignature (resourceId: UInt64, txIndex: UInt64, keyListIndex: Int, sig: [UInt8]): SignatureStore;
        pub fun readyForExecution(txIndex: UInt64): PayloadDetails?;
    }
    
    pub struct SignatureStore {
        // Keylist index
        pub(set) var keyListIndex: Int;
        
        // Transaction index
        pub(set) var txIndex: UInt64;

        // Signers and their weights
        pub let keyList: {Int: KeyListElement};

        // map of an assigned index and the payload
        // payload in this case is the script and argument
        pub var payloads: {UInt64: PayloadDetails}

        pub var payloadSigs: {UInt64: [Crypto.KeyListSignature]}

        init(initialSigners: [KeyListElement]){
            self.payloads = {};
            self.payloadSigs = {};
            self.keyList = {};
            self.keyListIndex = 0;
            self.txIndex = 0;
            
           for e in initialSigners {
               self.keyList.insert(key: self.keyListIndex, e);
               self.keyListIndex = self.keyListIndex + 1 as Int;
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
        pub fun addKey (newKeyListElement: KeyListElement): SignatureStore {
            self.signatureStore.keyList.insert(key: self.signatureStore.keyListIndex, newKeyListElement);
            self.signatureStore.keyListIndex = self.signatureStore.keyListIndex + 1 as Int;
            return self.signatureStore
        }

        // Currently not supporting MultiSig
        pub fun removeKey (keyListIndex: Int, keyListElement: KeyListElement): SignatureStore {
            pre {
                self.signatureStore.keyList.containsKey(keyListIndex): "keylist does not contain such key index"
            }
            self.signatureStore.keyList.remove(key: keyListIndex);
            return self.signatureStore
        }
        
        pub fun addNewPayload (resourceId: UInt64, payload: PayloadDetails, keyListIndex: Int, sig: [UInt8]): SignatureStore {
            // 1. check if the payloadSig is signed by one of the account's keys, preventing others from adding to storage
            if (self.verifyIsOneOfSigners(payload: payload, txIndex: nil, keyListIndex: keyListIndex, sig: sig) == false) {
                panic ("invalid signer")
            }

            // 2. increment index
            let txIndex = self.signatureStore.txIndex.saturatingAdd(1);
            self.signatureStore.txIndex = txIndex;

            // 3. call addPayloadSig to store the first sig for the index
            assert(!self.signatureStore.payloads.containsKey(txIndex), message: "Payload index already exist");
            self.signatureStore.payloads.insert(key: txIndex, payload);
            
            let sigs = [Crypto.KeyListSignature( keyIndex: keyListIndex, signature: sig)]
            self.signatureStore.payloadSigs.insert(
                key: txIndex, 
                sigs
            )
            
            emit NewPayloadAdded(resourceId: resourceId, txIndex: txIndex)
            return self.signatureStore
        }

        pub fun addPayloadSignature (resourceId: UInt64, txIndex: UInt64, keyListIndex: Int, sig: [UInt8]): SignatureStore {
            // 1. check if the the signer is the accounting owning this signer by using data as the one in payloads
            // 2. add to the sig
            // 3. if weight of all the signatures above threshold, call executeTransaction
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
        
        pub fun verifyIsOneOfSigners (payload: PayloadDetails?, txIndex: UInt64?, keyListIndex: Int, sig: [UInt8]): Bool {
            assert(payload != nil || txIndex != nil, message: "cannot verify signature without payload or txIndex");
            assert(!(payload != nil && txIndex != nil), message: "cannot verify signature without payload or txIndex");
            assert(self.signatureStore.keyList.containsKey(keyListIndex), message: "no signer stored for multisig")
            
            log(self.signatureStore.keyList[keyListIndex])
            let pk = PublicKey(
                publicKey: self.signatureStore.keyList[keyListIndex]!.publicKey.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
                //signatureAlgorithm: SignatureAlgorithm(rawValue: self.signatureStore.keyList[keyListIndex]!.sigAlgo) ?? panic ("invalid signature algo")
            )
            log("publicKey")
            log(pk)

            log("sig")
            log(sig)

            var payloadInBytes: [UInt8] = []

            if (payload != nil) {
                payloadInBytes = self.getSignableData(payload: payload!);
            } else {
                let p = self.signatureStore.payloads[txIndex!];
                payloadInBytes = self.getSignableData(payload: p!);
            }
            
            log("signable")
            log(payloadInBytes)
            
            let keylist = Crypto.KeyList()
            keylist.add(pk, hashAlgorithm: HashAlgorithm.SHA3_256, weight: 1.0)

            let signatureSet = [
                Crypto.KeyListSignature(
                    keyIndex: 0,
                    signature: sig
                )
            ]
            
            let isValid = keylist.verify(
                signatureSet: signatureSet,
                signedData: payloadInBytes 
            )

            return isValid
            // return pk.verify(
            //     signature: sig,
            //     signedData: payloadInBytes,
            //     domainSeparationTag: "FLOW-V0.0-user",
            //     hashAlgorithm: HashAlgorithm.SHA3_256
            // )
            
        }
        
        
        init(sigStore: SignatureStore) {
            self.signatureStore = sigStore;
        }
            
    }
}