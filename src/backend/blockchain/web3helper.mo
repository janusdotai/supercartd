import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Error "mo:base/Error";
import List "mo:base/List";
import Float "mo:base/Float";
import Types "../Types";
import HttpTypes "../http/http.types";
import Utils "../Utils";
import Hex "../Hex";
import Base64 "../Base64";
import { JSON; Candid; CBOR; } "mo:serde";
import HU "mo:evm-txs/utils/HashUtils";
import AU "mo:evm-txs/utils/ArrayUtils";
import TU "mo:evm-txs/utils/TextUtils";
import TokenF "./TokenFactory";

//General helper class to talk to web3 providers
//and call sc functions directly
module Web3Helper {    

    private let CHAINLINK_ABI : Text = "W3siaW5wdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJhZGRyZXNzIiwibmFtZSI6Il9hZ2dyZWdhdG9yIiwidHlwZSI6ImFkZHJlc3MifSx7ImludGVybmFsVHlwZSI6ImFkZHJlc3MiLCJuYW1lIjoiX2FjY2Vzc0NvbnRyb2xsZXIiLCJ0eXBlIjoiYWRkcmVzcyJ9XSwic3RhdGVNdXRhYmlsaXR5Ijoibm9ucGF5YWJsZSIsInR5cGUiOiJjb25zdHJ1Y3RvciJ9LHsiYW5vbnltb3VzIjpmYWxzZSwiaW5wdXRzIjpbeyJpbmRleGVkIjp0cnVlLCJpbnRlcm5hbFR5cGUiOiJpbnQyNTYiLCJuYW1lIjoiY3VycmVudCIsInR5cGUiOiJpbnQyNTYifSx7ImluZGV4ZWQiOnRydWUsImludGVybmFsVHlwZSI6InVpbnQyNTYiLCJuYW1lIjoicm91bmRJZCIsInR5cGUiOiJ1aW50MjU2In0seyJpbmRleGVkIjpmYWxzZSwiaW50ZXJuYWxUeXBlIjoidWludDI1NiIsIm5hbWUiOiJ1cGRhdGVkQXQiLCJ0eXBlIjoidWludDI1NiJ9XSwibmFtZSI6IkFuc3dlclVwZGF0ZWQiLCJ0eXBlIjoiZXZlbnQifSx7ImFub255bW91cyI6ZmFsc2UsImlucHV0cyI6W3siaW5kZXhlZCI6dHJ1ZSwiaW50ZXJuYWxUeXBlIjoidWludDI1NiIsIm5hbWUiOiJyb3VuZElkIiwidHlwZSI6InVpbnQyNTYifSx7ImluZGV4ZWQiOnRydWUsImludGVybmFsVHlwZSI6ImFkZHJlc3MiLCJuYW1lIjoic3RhcnRlZEJ5IiwidHlwZSI6ImFkZHJlc3MifSx7ImluZGV4ZWQiOmZhbHNlLCJpbnRlcm5hbFR5cGUiOiJ1aW50MjU2IiwibmFtZSI6InN0YXJ0ZWRBdCIsInR5cGUiOiJ1aW50MjU2In1dLCJuYW1lIjoiTmV3Um91bmQiLCJ0eXBlIjoiZXZlbnQifSx7ImFub255bW91cyI6ZmFsc2UsImlucHV0cyI6W3siaW5kZXhlZCI6dHJ1ZSwiaW50ZXJuYWxUeXBlIjoiYWRkcmVzcyIsIm5hbWUiOiJmcm9tIiwidHlwZSI6ImFkZHJlc3MifSx7ImluZGV4ZWQiOnRydWUsImludGVybmFsVHlwZSI6ImFkZHJlc3MiLCJuYW1lIjoidG8iLCJ0eXBlIjoiYWRkcmVzcyJ9XSwibmFtZSI6Ik93bmVyc2hpcFRyYW5zZmVyUmVxdWVzdGVkIiwidHlwZSI6ImV2ZW50In0seyJhbm9ueW1vdXMiOmZhbHNlLCJpbnB1dHMiOlt7ImluZGV4ZWQiOnRydWUsImludGVybmFsVHlwZSI6ImFkZHJlc3MiLCJuYW1lIjoiZnJvbSIsInR5cGUiOiJhZGRyZXNzIn0seyJpbmRleGVkIjp0cnVlLCJpbnRlcm5hbFR5cGUiOiJhZGRyZXNzIiwibmFtZSI6InRvIiwidHlwZSI6ImFkZHJlc3MifV0sIm5hbWUiOiJPd25lcnNoaXBUcmFuc2ZlcnJlZCIsInR5cGUiOiJldmVudCJ9LHsiaW5wdXRzIjpbXSwibmFtZSI6ImFjY2VwdE93bmVyc2hpcCIsIm91dHB1dHMiOltdLCJzdGF0ZU11dGFiaWxpdHkiOiJub25wYXlhYmxlIiwidHlwZSI6ImZ1bmN0aW9uIn0seyJpbnB1dHMiOltdLCJuYW1lIjoiYWNjZXNzQ29udHJvbGxlciIsIm91dHB1dHMiOlt7ImludGVybmFsVHlwZSI6ImNvbnRyYWN0IEFjY2Vzc0NvbnRyb2xsZXJJbnRlcmZhY2UiLCJuYW1lIjoiIiwidHlwZSI6ImFkZHJlc3MifV0sInN0YXRlTXV0YWJpbGl0eSI6InZpZXciLCJ0eXBlIjoiZnVuY3Rpb24ifSx7ImlucHV0cyI6W10sIm5hbWUiOiJhZ2dyZWdhdG9yIiwib3V0cHV0cyI6W3siaW50ZXJuYWxUeXBlIjoiYWRkcmVzcyIsIm5hbWUiOiIiLCJ0eXBlIjoiYWRkcmVzcyJ9XSwic3RhdGVNdXRhYmlsaXR5IjoidmlldyIsInR5cGUiOiJmdW5jdGlvbiJ9LHsiaW5wdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJhZGRyZXNzIiwibmFtZSI6Il9hZ2dyZWdhdG9yIiwidHlwZSI6ImFkZHJlc3MifV0sIm5hbWUiOiJjb25maXJtQWdncmVnYXRvciIsIm91dHB1dHMiOltdLCJzdGF0ZU11dGFiaWxpdHkiOiJub25wYXlhYmxlIiwidHlwZSI6ImZ1bmN0aW9uIn0seyJpbnB1dHMiOltdLCJuYW1lIjoiZGVjaW1hbHMiLCJvdXRwdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJ1aW50OCIsIm5hbWUiOiIiLCJ0eXBlIjoidWludDgifV0sInN0YXRlTXV0YWJpbGl0eSI6InZpZXciLCJ0eXBlIjoiZnVuY3Rpb24ifSx7ImlucHV0cyI6W10sIm5hbWUiOiJkZXNjcmlwdGlvbiIsIm91dHB1dHMiOlt7ImludGVybmFsVHlwZSI6InN0cmluZyIsIm5hbWUiOiIiLCJ0eXBlIjoic3RyaW5nIn1dLCJzdGF0ZU11dGFiaWxpdHkiOiJ2aWV3IiwidHlwZSI6ImZ1bmN0aW9uIn0seyJpbnB1dHMiOlt7ImludGVybmFsVHlwZSI6InVpbnQyNTYiLCJuYW1lIjoiX3JvdW5kSWQiLCJ0eXBlIjoidWludDI1NiJ9XSwibmFtZSI6ImdldEFuc3dlciIsIm91dHB1dHMiOlt7ImludGVybmFsVHlwZSI6ImludDI1NiIsIm5hbWUiOiIiLCJ0eXBlIjoiaW50MjU2In1dLCJzdGF0ZU11dGFiaWxpdHkiOiJ2aWV3IiwidHlwZSI6ImZ1bmN0aW9uIn0seyJpbnB1dHMiOlt7ImludGVybmFsVHlwZSI6InVpbnQ4MCIsIm5hbWUiOiJfcm91bmRJZCIsInR5cGUiOiJ1aW50ODAifV0sIm5hbWUiOiJnZXRSb3VuZERhdGEiLCJvdXRwdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJ1aW50ODAiLCJuYW1lIjoicm91bmRJZCIsInR5cGUiOiJ1aW50ODAifSx7ImludGVybmFsVHlwZSI6ImludDI1NiIsIm5hbWUiOiJhbnN3ZXIiLCJ0eXBlIjoiaW50MjU2In0seyJpbnRlcm5hbFR5cGUiOiJ1aW50MjU2IiwibmFtZSI6InN0YXJ0ZWRBdCIsInR5cGUiOiJ1aW50MjU2In0seyJpbnRlcm5hbFR5cGUiOiJ1aW50MjU2IiwibmFtZSI6InVwZGF0ZWRBdCIsInR5cGUiOiJ1aW50MjU2In0seyJpbnRlcm5hbFR5cGUiOiJ1aW50ODAiLCJuYW1lIjoiYW5zd2VyZWRJblJvdW5kIiwidHlwZSI6InVpbnQ4MCJ9XSwic3RhdGVNdXRhYmlsaXR5IjoidmlldyIsInR5cGUiOiJmdW5jdGlvbiJ9LHsiaW5wdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJ1aW50MjU2IiwibmFtZSI6Il9yb3VuZElkIiwidHlwZSI6InVpbnQyNTYifV0sIm5hbWUiOiJnZXRUaW1lc3RhbXAiLCJvdXRwdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJ1aW50MjU2IiwibmFtZSI6IiIsInR5cGUiOiJ1aW50MjU2In1dLCJzdGF0ZU11dGFiaWxpdHkiOiJ2aWV3IiwidHlwZSI6ImZ1bmN0aW9uIn0seyJpbnB1dHMiOltdLCJuYW1lIjoibGF0ZXN0QW5zd2VyIiwib3V0cHV0cyI6W3siaW50ZXJuYWxUeXBlIjoiaW50MjU2IiwibmFtZSI6IiIsInR5cGUiOiJpbnQyNTYifV0sInN0YXRlTXV0YWJpbGl0eSI6InZpZXciLCJ0eXBlIjoiZnVuY3Rpb24ifSx7ImlucHV0cyI6W10sIm5hbWUiOiJsYXRlc3RSb3VuZCIsIm91dHB1dHMiOlt7ImludGVybmFsVHlwZSI6InVpbnQyNTYiLCJuYW1lIjoiIiwidHlwZSI6InVpbnQyNTYifV0sInN0YXRlTXV0YWJpbGl0eSI6InZpZXciLCJ0eXBlIjoiZnVuY3Rpb24ifSx7ImlucHV0cyI6W10sIm5hbWUiOiJsYXRlc3RSb3VuZERhdGEiLCJvdXRwdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJ1aW50ODAiLCJuYW1lIjoicm91bmRJZCIsInR5cGUiOiJ1aW50ODAifSx7ImludGVybmFsVHlwZSI6ImludDI1NiIsIm5hbWUiOiJhbnN3ZXIiLCJ0eXBlIjoiaW50MjU2In0seyJpbnRlcm5hbFR5cGUiOiJ1aW50MjU2IiwibmFtZSI6InN0YXJ0ZWRBdCIsInR5cGUiOiJ1aW50MjU2In0seyJpbnRlcm5hbFR5cGUiOiJ1aW50MjU2IiwibmFtZSI6InVwZGF0ZWRBdCIsInR5cGUiOiJ1aW50MjU2In0seyJpbnRlcm5hbFR5cGUiOiJ1aW50ODAiLCJuYW1lIjoiYW5zd2VyZWRJblJvdW5kIiwidHlwZSI6InVpbnQ4MCJ9XSwic3RhdGVNdXRhYmlsaXR5IjoidmlldyIsInR5cGUiOiJmdW5jdGlvbiJ9LHsiaW5wdXRzIjpbXSwibmFtZSI6ImxhdGVzdFRpbWVzdGFtcCIsIm91dHB1dHMiOlt7ImludGVybmFsVHlwZSI6InVpbnQyNTYiLCJuYW1lIjoiIiwidHlwZSI6InVpbnQyNTYifV0sInN0YXRlTXV0YWJpbGl0eSI6InZpZXciLCJ0eXBlIjoiZnVuY3Rpb24ifSx7ImlucHV0cyI6W10sIm5hbWUiOiJvd25lciIsIm91dHB1dHMiOlt7ImludGVybmFsVHlwZSI6ImFkZHJlc3MgcGF5YWJsZSIsIm5hbWUiOiIiLCJ0eXBlIjoiYWRkcmVzcyJ9XSwic3RhdGVNdXRhYmlsaXR5IjoidmlldyIsInR5cGUiOiJmdW5jdGlvbiJ9LHsiaW5wdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJ1aW50MTYiLCJuYW1lIjoiIiwidHlwZSI6InVpbnQxNiJ9XSwibmFtZSI6InBoYXNlQWdncmVnYXRvcnMiLCJvdXRwdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJjb250cmFjdCBBZ2dyZWdhdG9yVjJWM0ludGVyZmFjZSIsIm5hbWUiOiIiLCJ0eXBlIjoiYWRkcmVzcyJ9XSwic3RhdGVNdXRhYmlsaXR5IjoidmlldyIsInR5cGUiOiJmdW5jdGlvbiJ9LHsiaW5wdXRzIjpbXSwibmFtZSI6InBoYXNlSWQiLCJvdXRwdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJ1aW50MTYiLCJuYW1lIjoiIiwidHlwZSI6InVpbnQxNiJ9XSwic3RhdGVNdXRhYmlsaXR5IjoidmlldyIsInR5cGUiOiJmdW5jdGlvbiJ9LHsiaW5wdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJhZGRyZXNzIiwibmFtZSI6Il9hZ2dyZWdhdG9yIiwidHlwZSI6ImFkZHJlc3MifV0sIm5hbWUiOiJwcm9wb3NlQWdncmVnYXRvciIsIm91dHB1dHMiOltdLCJzdGF0ZU11dGFiaWxpdHkiOiJub25wYXlhYmxlIiwidHlwZSI6ImZ1bmN0aW9uIn0seyJpbnB1dHMiOltdLCJuYW1lIjoicHJvcG9zZWRBZ2dyZWdhdG9yIiwib3V0cHV0cyI6W3siaW50ZXJuYWxUeXBlIjoiY29udHJhY3QgQWdncmVnYXRvclYyVjNJbnRlcmZhY2UiLCJuYW1lIjoiIiwidHlwZSI6ImFkZHJlc3MifV0sInN0YXRlTXV0YWJpbGl0eSI6InZpZXciLCJ0eXBlIjoiZnVuY3Rpb24ifSx7ImlucHV0cyI6W3siaW50ZXJuYWxUeXBlIjoidWludDgwIiwibmFtZSI6Il9yb3VuZElkIiwidHlwZSI6InVpbnQ4MCJ9XSwibmFtZSI6InByb3Bvc2VkR2V0Um91bmREYXRhIiwib3V0cHV0cyI6W3siaW50ZXJuYWxUeXBlIjoidWludDgwIiwibmFtZSI6InJvdW5kSWQiLCJ0eXBlIjoidWludDgwIn0seyJpbnRlcm5hbFR5cGUiOiJpbnQyNTYiLCJuYW1lIjoiYW5zd2VyIiwidHlwZSI6ImludDI1NiJ9LHsiaW50ZXJuYWxUeXBlIjoidWludDI1NiIsIm5hbWUiOiJzdGFydGVkQXQiLCJ0eXBlIjoidWludDI1NiJ9LHsiaW50ZXJuYWxUeXBlIjoidWludDI1NiIsIm5hbWUiOiJ1cGRhdGVkQXQiLCJ0eXBlIjoidWludDI1NiJ9LHsiaW50ZXJuYWxUeXBlIjoidWludDgwIiwibmFtZSI6ImFuc3dlcmVkSW5Sb3VuZCIsInR5cGUiOiJ1aW50ODAifV0sInN0YXRlTXV0YWJpbGl0eSI6InZpZXciLCJ0eXBlIjoiZnVuY3Rpb24ifSx7ImlucHV0cyI6W10sIm5hbWUiOiJwcm9wb3NlZExhdGVzdFJvdW5kRGF0YSIsIm91dHB1dHMiOlt7ImludGVybmFsVHlwZSI6InVpbnQ4MCIsIm5hbWUiOiJyb3VuZElkIiwidHlwZSI6InVpbnQ4MCJ9LHsiaW50ZXJuYWxUeXBlIjoiaW50MjU2IiwibmFtZSI6ImFuc3dlciIsInR5cGUiOiJpbnQyNTYifSx7ImludGVybmFsVHlwZSI6InVpbnQyNTYiLCJuYW1lIjoic3RhcnRlZEF0IiwidHlwZSI6InVpbnQyNTYifSx7ImludGVybmFsVHlwZSI6InVpbnQyNTYiLCJuYW1lIjoidXBkYXRlZEF0IiwidHlwZSI6InVpbnQyNTYifSx7ImludGVybmFsVHlwZSI6InVpbnQ4MCIsIm5hbWUiOiJhbnN3ZXJlZEluUm91bmQiLCJ0eXBlIjoidWludDgwIn1dLCJzdGF0ZU11dGFiaWxpdHkiOiJ2aWV3IiwidHlwZSI6ImZ1bmN0aW9uIn0seyJpbnB1dHMiOlt7ImludGVybmFsVHlwZSI6ImFkZHJlc3MiLCJuYW1lIjoiX2FjY2Vzc0NvbnRyb2xsZXIiLCJ0eXBlIjoiYWRkcmVzcyJ9XSwibmFtZSI6InNldENvbnRyb2xsZXIiLCJvdXRwdXRzIjpbXSwic3RhdGVNdXRhYmlsaXR5Ijoibm9ucGF5YWJsZSIsInR5cGUiOiJmdW5jdGlvbiJ9LHsiaW5wdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJhZGRyZXNzIiwibmFtZSI6Il90byIsInR5cGUiOiJhZGRyZXNzIn1dLCJuYW1lIjoidHJhbnNmZXJPd25lcnNoaXAiLCJvdXRwdXRzIjpbXSwic3RhdGVNdXRhYmlsaXR5Ijoibm9ucGF5YWJsZSIsInR5cGUiOiJmdW5jdGlvbiJ9LHsiaW5wdXRzIjpbXSwibmFtZSI6InZlcnNpb24iLCJvdXRwdXRzIjpbeyJpbnRlcm5hbFR5cGUiOiJ1aW50MjU2IiwibmFtZSI6IiIsInR5cGUiOiJ1aW50MjU2In1dLCJzdGF0ZU11dGFiaWxpdHkiOiJ2aWV3IiwidHlwZSI6ImZ1bmN0aW9uIn1d";

    public type EthJsonRpcRequest = {
        id: Int;
        jsonrpc: Text;
        method: Text;
        params: [EthJsonRpcParam];
    };

    public type EthJsonRpcParam = {
        data: ?Text;
        to: ?Text;        
    };

    public type EthJsonRpcResult = {
        id: ?Int;
        jsonrpc: ?Text;
        result: Text;
    };

    public type EthGetBlockNumberResponse = {
        block: Nat;
        block_encoded: Text;
    };

    public type ChainlinkLatesRoundData = {
        roundId: Nat;
        answer: Nat;
        startedAt: Nat;
        updatedAt: Nat;
        answeredInRound: Nat;
        decimals: Nat8;
    };
     
    
    public class Web3(_provider: Text, _testMode : Bool) {

        public let selected_provider : Text = _provider;

        public let TEST_MODE : Bool = _testMode;

        let ic : HttpTypes.IC = actor ("aaaaa-aa");

        //must support ipv6
        public let provider_whitelist = [
            "https://eth.llamarpc.com",
            "https://rpc.flashbots.net",
            "https://cloudflare-eth.com",
            "https://ethereum.publicnode.com",

            "https://rpc.ankr.com/optimism",       
            "https://sepolia.publicgoods.network"
        ];       

        private func _ent() : Text {
            return "scd web3 icp eth tests";
        };        

        private func pre_init() : Bool{    
            var result = false;
            assert(Text.size(selected_provider) > 10);
            let match =  Array.indexOf<Text>(selected_provider, provider_whitelist, Text.equal);
            if(match == null){
                Debug.print("ERROR web3.pre_init provider safe list match: " # debug_show(selected_provider));
                return false;
            };            
            result := true;            
            return result;
        };


        public func eth_chainId() : async Nat {
            assert(pre_init() == true);
            let request : EthJsonRpcRequest = {
                id = 0;
                jsonrpc = "2.0";
                method = "eth_chainId";
                params = [];
            };
            let response = await callEVM(request);            
            let stripped = safeTransformEvm(response.result);
            let #ok(h) = Hex.decode(stripped) else return 0;            
            var safeValue = AU.toNat256(h);            
            return safeValue;
        };        

        public func eth_blockNumber() : async EthGetBlockNumberResponse{
            assert(pre_init() == true);
            let request : EthJsonRpcRequest = {
                id = 0;
                jsonrpc = "2.0";
                method = "eth_blockNumber";
                params = [];
            };            
            let response = await callEVM(request);            
            let stripped = safeTransformEvm(response.result);
            let #ok(h) = Hex.decode(stripped) else return { block = 0; block_encoded = "";  };            
            var safeValue = AU.toNat256(h);            
            let r : EthGetBlockNumberResponse = {
                block = safeValue;
                block_encoded = response.result;
            };
            return r;
        };

        public func eth_gasPrice() : async Nat {
            assert(pre_init() == true);
            let request : EthJsonRpcRequest = {
                id = 0;
                jsonrpc = "2.0";
                method = "eth_gasPrice";
                params = [];
            };            
            let response = await callEVM(request);            
            let stripped = safeTransformEvm(response.result);
            let #ok(h) = Hex.decode(stripped) else return 0;
            var safeValue = AU.toNat256(h);
            return safeValue;
        };

        public func chainlink_latestPriceUSD(_selected_token : Types.TokenCurrency) : async Text{
            var result = "0.0";
            var round = await chainlink_getLatestRound(_selected_token);
            switch(round){
                case null return result;
                case(?round){
                    //btc: 4310924367310
                    //decimals: 8
                    let amt = round.answer;    
                    let decimals = round.decimals;                
                    var usd = insertDecmialForChainlinkRound(Nat.toText(amt), decimals);                    
                    Debug.print("chainlink_latestPriceUSD " # debug_show(usd));
                    return usd;
                };
            };
            return result;
        };

         //get latest price according to chainlink latestRoundData
        public func chainlink_latestFxRateUSD(_currency : Types.Currency) : async Text{
            var result = "0.0"; //todo
            var round = await chainlink_getCurrencyExchangeRate(_currency);
            switch(round){
                case null return result;
                case(?round){
                    //btc: 4310924367310
                    //decimals: 8
                    let amt = round.answer;    
                    let decimals = round.decimals;                
                    var usd = insertDecmialForChainlinkRound(Nat.toText(amt), decimals);                    
                    return usd;
                };
            };
            return result;
        };
        
        //calls chainlink feed for latest round data
        private func chainlink_getLatestRound(_selected_token : Types.TokenCurrency) : async ?ChainlinkLatesRoundData {
            assert(pre_init() == true);
            let abi = decode_abi(CHAINLINK_ABI);
            let mappings = [
                (#icp, "0xe98290265E4aE3758503a03e937F381A2A7aFB57", 8), //optimism contract for
                (#eth, "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419", 8), //chailink uses custom decimals
                (#btc, "0xf4030086522a5beea4988f8ca5b36dbc97bee88c", 8),
                (#sol, "0x4ffc43a60e009b551865a93d232e33fce9f01507", 8),
                (#weth, "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419", 8),
                (#usdt, "0x3e7d1eab13ad0104d2750b8863b489d65364e32d", 8),
                (#dai, "0xaed0c38402a5d19df6e4c03f4e2dced6e29c1ee9", 8),
                (#usdc, "0x8fffffd4afb6115b954bd326cbe7b4ba576818f6", 8),
                (#ckbtc, "", 8),
                (#cketh, "", 8),
                (#bonk, "0xec236454209A76a6deCdf5C1183aE2Eb5e82a829", 8), //optimism
                (#wbtc, "0xf4030086522a5beea4988f8ca5b36dbc97bee88c", 8)
            ];
            let match = Array.find<(Types.TokenCurrency, Text, Nat)>(mappings, func(x) = x.0 == _selected_token);
            switch(match){
                case null {
                    Debug.print("ERROR no mapping for chainlink_getLatestRound found for " # debug_show(_selected_token));
                    return null;
                };
                case (?match){
                    let token = match.0;        
                    let contract = match.1;                    
                    let decimals = match.2;                   
                    if(Text.size(contract) == 0 or decimals == 0){
                        Debug.print("ERROR - NO CHAINLINK MAPPING FOUND: " # debug_show(token));
                        return null;
                    };

                    let p : EthJsonRpcParam = {
                        data = ?"0xfeaf968c"; //lastRoundData
                        to = ?contract;
                    };                    

                    let req : EthJsonRpcRequest = {
                        id = 1;
                        jsonrpc = "2.0";
                        method = "eth_call";                        
                        params = [p];
                    };
                    
                    let res = await callEVM(req);
                    Debug.print("callChainlinkFeed call result : " # debug_show(res));
                    let encoded_response = res.result;
                    if(encoded_response == "0x" or encoded_response == "0X"){
                        Debug.print("callChainlinkFeed ERROR no result returned " # debug_show(res));
                        return null;
                    };

                    let bytes = AU.fromText(encoded_response);
                    Debug.print("AU.fromText size: " # debug_show(Array.size(bytes)));
                    //Debug.print("AU.fromText : " # debug_show(bytes));                    
                    //assert(Array.size(bytes) > 132);
                    assert(Array.size(bytes) == 160);
                    
                    //roundId uint80, answer int256, startedAt uint256, updatedAt uint256, answeredInRound uint80
                    let roundData = Array.subArray(bytes, 0, 32);
                    let roundId = AU.toNat256(roundData);
                    Debug.print("AU.toNat roundId : " # debug_show(roundId));

                    let answerData = Array.subArray(bytes, 32, 32);
                    let answer = AU.toNat256(answerData);
                    Debug.print("AU.toNat answer : " # debug_show(answer));

                    let startedAtData = Array.subArray(bytes, 64, 32);
                    let startedAt = AU.toNat256(startedAtData);
                    Debug.print("AU.toNat startedAt : " # debug_show(startedAt));

                    let updatedAtData = Array.subArray(bytes, 96, 32);
                    let updatedAt = AU.toNat256(updatedAtData);
                    Debug.print("AU.toNat updatedAt : " # debug_show(updatedAt));

                    let answeredInRoundData = Array.subArray(bytes, 128, 32);
                    let answeredInRound = AU.toNat256(answeredInRoundData);
                    Debug.print("AU.toNat answeredInRound : " # debug_show(answeredInRound));

                    let result : ChainlinkLatesRoundData = {
                        roundId = roundId;
                        answer = answer;
                        startedAt = startedAt;
                        updatedAt = updatedAt;
                        answeredInRound = answeredInRound;
                        decimals = Nat8.fromNat(decimals);
                    };
                    Debug.print("ChainlinkLatesRoundData : " # debug_show(result));
                    return ?result;
                };
            };
            return null;
        };   

        //calls chainlink feed for latest fx round data
        public func chainlink_getCurrencyExchangeRate(_currency : Types.Currency) : async ?ChainlinkLatesRoundData {
            assert(pre_init() == true);            
            let abi = decode_abi(CHAINLINK_ABI);
            let mappings = [
                (#usd, "0xa34317db73e77d453b1b8d04550c44d10e981c8e", 8), //chailink uses custom decimals
                (#cad, "0xa34317db73e77d453b1b8d04550c44d10e981c8e", 8), 
                (#eur, "0xb49f677943bc038e9857d61e7d053caa2c1734c1", 8),
                (#gbp, "0x5c0ab2d9b5a7ed9f470386e82bb36a3613cdd4b5", 8),
                (#chf, "0x449d117117838fFA61263B61dA6301AA2a88B13A", 8)                
            ];
            let match = Array.find<(Types.Currency, Text, Nat)>(mappings, func(x) = x.0 == _currency);
            switch(match){
                case null {
                    Debug.print("ERROR no mapping for chainlink_getCurrencyExchangeRate found for " # debug_show(_currency));
                    return null;
                };
                case (?match){
                    let countryCode = match.0;        
                    let contract = match.1;                    
                    let decimals = match.2;

                    if(Text.size(contract) == 0 or decimals == 0){
                        Debug.print("ERROR - NO CHAINLINK MAPPING FOUND: " # debug_show(countryCode));
                        return null;
                    };

                    let p : EthJsonRpcParam = {
                        data = ?"0xfeaf968c"; //lastRoundData
                        to = ?contract;
                    };                    

                    let req : EthJsonRpcRequest = {
                        id = 1;
                        jsonrpc = "2.0";
                        method = "eth_call";                        
                        params = [p];
                    };
                    
                    let res = await callEVM(req);                    
                    let encoded_response = res.result;
                    if(encoded_response == "0x" or encoded_response == "0X"){
                        Debug.print("callChainlinkFeed ERROR no result returned " # debug_show(res));
                        return null;
                    };

                    let bytes = AU.fromText(encoded_response);
                    Debug.print("AU.fromText size: " # debug_show(Array.size(bytes)));
                    assert(Array.size(bytes) == 160);
                    
                    //roundId uint80, answer int256, startedAt uint256, updatedAt uint256, answeredInRound uint80
                    let roundData = Array.subArray(bytes, 0, 32);
                    let roundId = AU.toNat256(roundData);
                    Debug.print("AU.toNat roundId : " # debug_show(roundId));

                    let answerData = Array.subArray(bytes, 32, 32);
                    let answer = AU.toNat256(answerData);
                    Debug.print("AU.toNat answer : " # debug_show(answer));

                    let startedAtData = Array.subArray(bytes, 64, 32);
                    let startedAt = AU.toNat256(startedAtData);
                    Debug.print("AU.toNat startedAt : " # debug_show(startedAt));

                    let updatedAtData = Array.subArray(bytes, 96, 32);
                    let updatedAt = AU.toNat256(updatedAtData);
                    Debug.print("AU.toNat updatedAt : " # debug_show(updatedAt));

                    let answeredInRoundData = Array.subArray(bytes, 128, 32);
                    let answeredInRound = AU.toNat256(answeredInRoundData);
                    Debug.print("AU.toNat answeredInRound : " # debug_show(answeredInRound));                 

                    let result : ChainlinkLatesRoundData = {
                        roundId = roundId;
                        answer = answer;
                        startedAt = startedAt;
                        updatedAt = updatedAt;
                        answeredInRound = answeredInRound;
                        decimals = Nat8.fromNat(decimals);
                    };
                    Debug.print("ChainlinkLatesRoundData FX: " # debug_show(result));
                    return ?result;
                };
            };
            return null;
        };          
        
        //calls JSON RPC EVM provider
        private func callEVM(request : EthJsonRpcRequest) : async EthJsonRpcResult {
            let e = _ent();
            let before : Text = Text.concat(e # selected_provider, Nat64.toText(Utils.now()));                        
            let idempotencyKey = Utils.textToSha(before);
            var result : EthJsonRpcResult = {
                id = ?0;
                jsonrpc = ?"2.0";
                result = "";
            };
            
            let keys = ["id", "jsonrpc", "method", "params", "data", "to"];            
            let blob = to_candid(request);
            let #ok(jsonRequest) = JSON.toText(blob, keys, null) else return result;
            Debug.print("Set jsonRequest: " # debug_show(jsonRequest));

            let requestBodyAsBlob : Blob = Text.encodeUtf8(jsonRequest);
            let requestBodyAsNat8 : [Nat8] = Blob.toArray(requestBodyAsBlob);            
            
            let httpRequest : HttpTypes.HttpRequestArgs = {
                url = selected_provider;
                max_response_bytes = ?Nat64.fromNat(2000); //todo
                headers = [
                    { name = "Content-Type"; value = "application/json" },
                    { name = "Idempotency-Key"; value = idempotencyKey },
                ];
                body = ?requestBodyAsNat8;
                method = #post;
                transform = null;
            };
                                
            Cycles.add(1_000_000_000);
            
            let httpResponse : HttpTypes.HttpResponsePayload = await ic.http_request(httpRequest);
            Debug.print("HttpResponsePayload STATUS: " # debug_show(httpResponse.status));    
            if (httpResponse.status == 200) {                
                let response_body : Blob = Blob.fromArray(httpResponse.body);
                let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
                    case (null) { "No value returned from service" };
                    case (?decoded_text) {
                        Debug.print("Decoded text: " # debug_show(decoded_text));
                        let #ok(blob) = JSON.fromText(decoded_text, null) else return result; 
                        let ethJsonResult : ?EthJsonRpcResult = from_candid(blob);
                        Debug.print("EthJsonRpcResult deserialized: " # debug_show(ethJsonResult));                        
                        switch(?ethJsonResult){
                            case null return result;
                            case(?ethJsonResult){                                
                                Debug.print("EthJsonRpcResult success parsed case: " # debug_show(ethJsonResult)); 
                                let thing = Option.get<EthJsonRpcResult>(ethJsonResult, result);
                                return thing;                             
                            };
                        };
                    };
                };
                Debug.print("HttpResponsePayload "  # debug_show(httpResponse));
                return result;
            } else {
                Debug.print("HttpResponsePayload "  # debug_show(httpResponse));
                return result;
            };
        };

        
        //inserts a decimal point at the specified decimal_index
        private func insertDecmialForChainlinkRound(inputText : Text, decimal_index : Nat8) : Text {            
            var result = "";
            let original = Text.toArray(inputText); //4_721_027_000_000
            let len = original.size();
            let decimal = Nat8.toNat(decimal_index);
            if(len < 5 or len < decimal){
                Debug.print("ERROR insertDecmialForChainlinkRound INVALID STRING " # debug_show(len));
                return "0";
            };
            var b = Buffer.fromArray<Char>(original); //[4,7,2,1,0,2,7,0,0,0,0,0,0]
            Buffer.reverse(b);
            b.insert(decimal, '.');
            Buffer.reverse(b);
            let final = Buffer.toArray(b);            
            return Text.fromIter(final.vals());
        };


        /* ----------------- TRANSACTIONS ------------------- */
        public func getTransactionReceipt(hash : Text, chain : Types.TokenChain, token : Types.TokenCurrency) : async ?Types.TransactionReceipt {

            //  --data '
            //     {
            //     "id": 1,
            //     "jsonrpc": "2.0",
            //     "method": "eth_getTransactionReceipt",
            //     "params": [
            //         "0x..."
            //     ]
            //     }
            //DATA, 32 Bytes - hash of a transaction
            // params: [ 
            // '0x...' 
            // ]    

            assert(pre_init() == true);
            assert(Text.size(hash) == 66);            

            let p : EthJsonRpcParam = {
                data = ?hash;
                to = null;
            };
            let request : EthJsonRpcRequest = {
                id = 0;
                jsonrpc = "2.0";
                method = "eth_getTransactionReceipt";
                params = [p];
            };            
            let response = await callEVM(request);            

            // let stripped = safeTransformEvm(response.result);
            // let #ok(h) = Hex.decode(stripped) else return 0;            
            // var safeValue = AU.toNat256(h);            
            // return safeValue;

            Debug.print("getTransactionReceipt " );
            Debug.print("result " # debug_show(response) );

            let r : Types.TransactionReceipt = {
                status = false;
                transactionHash = "";
                transactionIndex =  0;
                blockHash = "";
                blockNumber = 0;
                contractAddress = "";
                cumulativeGasUsed = 0;
                gasUsed = 0;
                chain = chain;
                token_type = token;
            };

            return ?r;
        };

        private func decode_abi(b64abi : Text) : ?Text {
            let blob = Text.encodeUtf8(b64abi);
            let array = Blob.toArray(blob);
            let #ok(decoded) = Base64.URLEncoding.decode(array) else return null;           
            let b = Blob.fromArray(decoded);            
            let final = Text.decodeUtf8(b);            
            return final;
        };

        private func safeTransformEvm(s : Text) : Text{
            if(Text.size(s) == 0){
                return "";
            };
            if(Text.startsWith(s, #text "0x") or Text.startsWith(s, #text "0X")){
                let stripped = Utils.subString(s, 2, Text.size(s) - 2);                
                return stripped;
            };
            return s;
        };

    };

};

