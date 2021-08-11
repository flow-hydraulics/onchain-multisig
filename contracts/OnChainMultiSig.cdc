import Crypto

pub contract OnChainMultiSig {
    
    pub event NewPayloadAdded(resourceId: UInt64, txIndex: UInt64);
    pub event NewPayloadSigAdded(resourceId: UInt64, txIndex: UInt64);

    pub struct PayloadDetails {
        pub var txIndex: UInt64;
        pub var method: String;
        pub var args: [AnyStruct];
        
        init(txIndex: UInt64, method: String, args: [AnyStruct]) {
            self.txIndex = txIndex;
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
        pub fun addNewPayload(payload: PayloadDetails, publicKey: String, sig: [UInt8]);
        pub fun addPayloadSignature (txIndex: UInt64, publicKey: String, sig: [UInt8]);
        pub fun executeTx(txIndex: UInt64): @AnyResource?;
        pub fun UUID(): UInt64;
        pub fun getTxIndex(): UInt64;
        pub fun getSignerKeys(): [String];
        pub fun getSignerKeyAttr(publicKey: String): PubKeyAttr?;
    }
    
    pub resource interface KeyManager {
        pub fun addKeys( multiSigPubKeys: [String], multiSigKeyWeights: [UFix64]);
        pub fun removeKeys( multiSigPubKeys: [String]);
    }
    
    pub resource interface SignatureManager {
        pub fun getSignableData(payload: PayloadDetails): [UInt8];
        pub fun getSignerKeys(): [String];
        pub fun getSignerKeyAttr(publicKey: String): PubKeyAttr?;
        pub fun addNewPayload (resourceId: UInt64, payload: PayloadDetails, publicKey: String, sig: [UInt8]);
        pub fun addPayloadSignature (resourceId: UInt64, txIndex: UInt64, publicKey: String, sig: [UInt8]);
        pub fun readyForExecution(txIndex: UInt64): PayloadDetails?;
        pub fun configureKeys (pks: [String], kws: [UFix64]);
        pub fun removeKeys (pks: [String]);
        pub fun verifySigners (payload: PayloadDetails?, txIndex: UInt64?, pks: [String], sigs: [Crypto.KeyListSignature]): UFix64?;
    }

    pub resource Manager: SignatureManager {
        
        // Transaction index
        // This value is not settable
        pub var txIndex: UInt64;

        // Signers and their weights
        // String in hex to be decoded as [UInt8], without "0x" prefix
        access(self) let keyList: {String: PubKeyAttr};

        // map of an assigned index and the payload
        // payload in this case is the script and argument
        access(self) let payloads: {UInt64: PayloadDetails}

        access(self) let payloadSigs: {UInt64: PayloadSigDetails}

        pub fun getSignerKeys(): [String] {
            return self.keyList.keys
        }

        pub fun getSignerKeyAttr(publicKey: String): PubKeyAttr? {
            return self.keyList[publicKey]
        }

        pub fun getSignableData(payload: PayloadDetails): [UInt8] {
            var s = payload.txIndex.toBigEndianBytes();
            s = s.concat(payload.method.utf8);
            for a in payload.args {
                var b: [UInt8] = [];
                switch a.getType() {
                    case Type<String>():
                        let temp = a as? String;
                        b = temp!.utf8; 
                    case Type<UInt64>():
                        let temp = a as? UInt64;
                        b = temp!.toBigEndianBytes(); 
                    case Type<UFix64>():
                        let temp = a as? UFix64;
                        b = temp!.toBigEndianBytes(); 
                    case Type<Address>():
                        let temp = a as? Address;
                        b = temp!.toBytes(); 
                    default:
                        panic ("Payload arg type not supported")
                }
                s = s.concat(b);
            }
            return s; 
        }
        
        pub fun configureKeys (pks: [String], kws: [UFix64]) {
            var i: Int =  0;
            while (i < pks.length) {
                let a = PubKeyAttr(sa: 1, w: kws[i])
                self.keyList.insert(key: pks[i], a)
                i = i + 1;
            }
        }

        pub fun removeKeys (pks: [String]) {
            var i: Int =  0;
            while (i < pks.length) {
                self.keyList.remove(key:pks[i])
                i = i + 1;
            }
        }
        
        pub fun addNewPayload (resourceId: UInt64, payload: PayloadDetails, publicKey: String, sig: [UInt8]) {
            assert(self.keyList.containsKey(publicKey), message: "Public key is not a registered signer");

            let txIndex = self.txIndex + UInt64(1);
            assert(payload.txIndex == txIndex, message: "Incorrect txIndex provided in paylaod")
            assert(!self.payloads.containsKey(txIndex), message: "Payload index already exist");
            self.txIndex = txIndex;

            // The keyIndex is also 0 for the first key
            let keyListSig = [Crypto.KeyListSignature(keyIndex: 0, signature: sig)]

            // check if the payloadSig is signed by one of the account's keys, preventing others from adding to storage
            let approvalWeight = self.verifySigners(payload: payload, txIndex: nil, pks: [publicKey], sigs: keyListSig)
            if ( approvalWeight == nil) {
                panic ("invalid signer")
            }

            self.payloads.insert(key: txIndex, payload);

            let payloadSigDetails = PayloadSigDetails(
                    keyListSignatures: keyListSig,
                    pubKeys: [publicKey]
                )
            
            self.payloadSigs.insert(
                key: txIndex, 
                payloadSigDetails 
            )
            
            emit NewPayloadAdded(resourceId: resourceId, txIndex: txIndex)
        }

        pub fun addPayloadSignature (resourceId: UInt64, txIndex: UInt64, publicKey: String, sig: [UInt8]) {
            assert(self.payloads.containsKey(txIndex), message: "Payload has not been added");
            assert(self.keyList.containsKey(publicKey), message: "Public key is not a registered signer");

            // This is a temp keyListSig list that is used to verify a single signature so we use keyIndex as 0
            // The correct keyIndex will overwrite the 0 after we know it is a valid signature
            var keyListSig = Crypto.KeyListSignature( keyIndex: 0, signature: sig)

            // check if the payloadSig is signed by one of the account's keys, preventing others from adding to storage
            let approvalWeight = self.verifySigners(payload: nil, txIndex: txIndex, pks: [publicKey], sigs: [keyListSig])
            if ( approvalWeight == nil) {
                panic ("invalid signer")
            }

            let currentIndex = self.payloadSigs[txIndex]!.keyListSignatures.length
            keyListSig = Crypto.KeyListSignature(keyIndex: currentIndex, signature: sig)
            self.payloadSigs[txIndex]!.keyListSignatures.append(keyListSig);
            self.payloadSigs[txIndex]!.pubKeys.append(publicKey);

            emit NewPayloadSigAdded(resourceId: resourceId, txIndex: txIndex)
        }

        pub fun readyForExecution(txIndex: UInt64): PayloadDetails? {
            assert(self.payloads.containsKey(txIndex), message: "No payload for such index");
            let pks = self.payloadSigs[txIndex]!.pubKeys;
            let sigs = self.payloadSigs[txIndex]!.keyListSignatures;
            let approvalWeight = self.verifySigners(payload: nil, txIndex: txIndex, pks: pks, sigs: sigs)
            if (approvalWeight == nil) {
                return nil
            }
            if (approvalWeight! >= 1000.0) {
                self.payloadSigs.remove(key: txIndex)!;
                let pd = self.payloads.remove(key: txIndex)!;
                return pd
            } else {
                return nil
            }
        }
        
        pub fun verifySigners (payload: PayloadDetails?, txIndex: UInt64?, pks: [String], sigs: [Crypto.KeyListSignature]): UFix64? {
            assert(payload != nil || txIndex != nil, message: "cannot verify signature without payload or txIndex");
            assert(!(payload != nil && txIndex != nil), message: "cannot verify signature without payload or txIndex");
            assert(pks.length == sigs.length, message: "cannot verify signatures without corresponding public keys");
            
            var totalAuthorisedWeight: UFix64 = 0.0;
            var keyList = Crypto.KeyList();
            var payloadInBytes: [UInt8] = []
            if (payload != nil) {
                payloadInBytes = self.getSignableData(payload: payload!);
            } else {
                let p = self.payloads[txIndex!];
                payloadInBytes = self.getSignableData(payload: p!);
            }

            var i = 0;
            while (i < pks.length) {
                // Check if the public key is a registered signer
                if (self.keyList[pks[i]] == nil){
                    continue;
                }

                let pk = PublicKey(
                    publicKey: pks[i].decodeHex(),
                    signatureAlgorithm: SignatureAlgorithm(rawValue: self.keyList[pks[i]]!.sigAlgo) ?? panic ("invalid signature algo")
                )
                
                keyList.add(
                    pk, 
                    hashAlgorithm: HashAlgorithm.SHA3_256,
                    weight: self.keyList[pks[i]]!.weight
                )
                totalAuthorisedWeight = totalAuthorisedWeight + self.keyList[pks[i]]!.weight
                i = i + 1;
            }
            
            let isValid = keyList.verify(
                signatureSet: sigs,
                signedData: payloadInBytes,
            )
            if (isValid) {
                return totalAuthorisedWeight
            } else {
                return nil
            }
            
        }
        
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
    
    pub fun createMultiSigManager(publicKeys: [String], pubKeyAttrs: [PubKeyAttr]): @Manager {
        return <- create Manager(publicKeys: publicKeys, pubKeyAttrs: pubKeyAttrs)
    }
}