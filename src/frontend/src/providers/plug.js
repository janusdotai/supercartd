
import { handleGlobalConnectionEvent, WalletProvider } from './index.js';
import { getAccountIdFromPrincipal, key2val, generateSHA256, pushNotify, ellipsis } from "../store/utils.js"
import { convertStringToE8s, uint8ArrayToHexString } from "@dfinity/utils";
import { LOADING, removeBusy } from "../store/loader.js";

import ic from 'ic0';

const LEDGER_ID = "ockk2-xaaaa-aaaai-aaaua-cai"
const NATIVE_ICP = "ryjl3-tyaaa-aaaaa-aaaba-cai";

class PlugWallet{   

    constructor(x){
        console.log("plug constructor was called with arg: " + x);
        this.active_wallet = "";        
        this.web3 = null;
        this.status_msg = null;
        this.status = 0;
        this.chain_id = x || "Internet Computer";
    }

    chainId(){
        return this.chain_id;
    }

    onInit(){
        console.log("plug init called")        
        document.getElementById("connection_status").innerHTML = "Plug Wallet - Request permission init"       
    }

    async disconnect(){
        console.log("plug was disconnected")
    }   

    async isConnected(){
        return await window.ic.plug.isConnected();
    }

    async login(){
        try{           
            
            const p = await window.ic.plug.requestConnect()
            //console.log(p)
            
            // access session principalId
            //console.log(window.ic.plug.principalId)

            // access session accountId
            //console.log(window.ic.plug.accountId)

            // access session agent
            // console.log(window.ic.plug.agent)
            var agent = window.ic.plug.agent;      
            
            var plug_principal_id = window.ic.plug.principalId ?? "unknown"
           
            this.active_wallet = plug_principal_id;
            this.chain_id = "Internet Computer"

            document.getElementById("chain_status").innerHTML = this.chainId();

             // Callback to print sessionData
            // const onConnectionUpdate = () => {
            //     console.log(window.ic.plug.sessionManager.sessionData)
            // }

            this.handleAuthenticated(agent, plug_principal_id)
            pushNotify("success", "Plug Wallet", "Connected");

            return true;

        }catch({name, message}){           
            //console.log(name)
            //console.log(message)
            if(message == "The agent creation was rejected."){
                document.getElementById("connection_status").innerHTML = "Plug - User rejected request"                
            }else{
                document.getElementById("connection_status").innerHTML = "Error - Plug wallet not found"
            }
        }
    }

    async handleAuthenticated(authClient, principalId){
        console.log("plug wallet handleAuthenticated ")
        //console.log("authClient")
        //console.log(authClient)
        let p = ellipsis(principalId, 12);        
        document.getElementById("connection_status").innerHTML = p;
        //handleGlobalConnectionEvent(principalId, authClient, WalletProvider.PLUG_WALLET);        
    }

    async getBalance(){
        const result = await window.ic.plug.requestBalance();
        console.log(result);
        return result;      
    }

    async proposeTransaction(provider, from, to, token_denomination, token_contract){
        if(provider !== WalletProvider.PLUG_WALLET){
            alert("Wrong provider")
            return false;
        }
        // console.log("plug proposeTransaction")
        // console.log("provider " + provider)
        // console.log("from " + from)
        // console.log("to" + to)   
        // console.log("token denomination " + token_denomination)
        // console.log("token_contract " + token_contract)

       // token_denomination = "180043500"; 1.7 icp for 22.344 cart
        //var token_amount = convertStringToE8s(token_denomination);
        //console.log(token_amount)

        const cartAmount = Number(token_denomination);
        const receiver = to;
        const requestTransferArg = {
            to: receiver,
            amount: cartAmount
            //memo: 123454
        };

        //TODO: ICRC1
        const tokenRequestTransferArg = {
            to: receiver,
            strAmount: '1.0', //todo icrc1 not working atm with this plug version
            token: token_contract
        };
        
        try{
            var connected = await this.isConnected();
            if(!connected){
                console.log("wallet not connected");
                return 0;
            }

            LOADING.setLoading(true, "Processing ... ");      
            pushNotify("info", "Plug Wallet", "Waiting ...");

            var transfer = null;
            if(token_contract.toLowerCase() == NATIVE_ICP.toLowerCase()){
                console.log("PLUG native icp")
                transfer = await window.ic.plug.requestTransfer(requestTransferArg);
            }else{ //ICRC1
                console.log("PLUG ICRC1 to " + token_contract)
                //transfer = await window.ic.plug.requestTransferToken(tokenRequestTransferArg);
                throw new Error("waiting for next plug extension release")
            }

            //console.log(transfer)
            var block = transfer?.height || 0;
            console.log(block);
            if(block > 0){
                LOADING.setLoading(true, "Confirming block ... please wait ");
                //document.getElementById("connection_status").innerHTML = "VALIDATING - Please wait...";
                pushNotify("info", "Plug Wallet", "Confirming block " + block );

                //const validated_client_side = await this.validateTransaction(block);
                const tx_validation_result = await this.validateTransaction(block);
                if(tx_validation_result.result === false){
                    document.getElementById("connection_status").innerHTML = "Error - Plug wallet failed to send";
                    throw Error("failed to validate block locally")                    
                }

                document.getElementById("connection_status").innerHTML = "Success - Plug wallet sent funds";
                
                let tx_hash = tx_validation_result.tx;
                let block_mined = tx_validation_result.block;
                if(block_mined != block){
                    console.log('index dont match?')
                }
                
                let return_tx = { "transactionHash": tx_hash.toString(), "cumulativeGasUsed": "", "blockNumber" : block_mined.toString() };
                LOADING.setLoading(false, "Success!");
                pushNotify("success", "Plug Wallet", "Success!");
                return return_tx;

            }else{
                document.getElementById("connection_status").innerHTML = "Error - Plug wallet failed to send";
            }           

        }catch({name, message}){
            console.log(name)
            console.log(message)        
            document.getElementById("connection_status").innerHTML = message;
            document.querySelector(".connection_status").innerHTML = message;
            document.querySelectorAll(".connection_status").forEach(x => {
                x.classList.add("pico-color-red-500");
            });        
            LOADING.setLoading(false, "");
        }
        return 0;
    }

    //validates a block on the client side
    async validateTransaction(block){

        console.log("validating block " + block)        
        const ledger = ic(LEDGER_ID); // Ledger canister        
        try{

            const thing = await ledger.call('block', block);
            console.log(thing);

            var transaction = thing?.Ok?.Ok?.transaction;
            console.log(transaction);

            if(!transaction){
                return { "result": false, "tx": "" };
            };
            
            //var parent_hash_thing = thing?.Ok?.Ok?.parent_hash[0];
            //let parent_hash = parent_hash_thing["inner"] || [] //Object { inner: Uint8Array(32) }
            //console.log(parent_hash)
            //if(parent_hash.length == 0){
            //    return { "result": false, "tx": "" };
            //};
            //let tx_hash = uint8ArrayToHexString(parent_hash);            

            let tx_hash = block; //tod cbor + sha
            var transfer = transaction?.transfer;
            var send = transfer?.Send;
            var amount = send.amount;
            var from = send.from;
            var to = send.to;
            var e8s = key2val(amount);
            console.log(`parsed block for amount ${e8s} send from ${from} to ${to}`)
            console.log(`tx ${tx_hash}`)

            return { "result": true, "tx": tx_hash, "block": block };

        }catch(e){
            console.log(e)
            pushNotify("error", "Plug Wallet", "Error validating transaction")            
        }
        return { "result": false, "tx": "" };
    }
    
    //todo how to get transaction hash from block
    // async test_block(block){
      
    //     const serializer = SelfDescribeCborSerializer.withDefaultEncoders(true);        

    //     const ledger = ic(LEDGER_ID); // Ledger canister      
    //     const thing = await ledger.call('block', block);
    //     console.log(thing);  

    //     var transaction = thing?.Ok?.Ok?.transaction;
    //     console.log(transaction);        
    //     //let x = new JsonDefaultCborEncoder();
        
    //     let encoded = serializer.serialize(transaction)
    //     let encoded2 = serializer.serializeValue(transaction)
    //     //var initial = { Hello: "World" };
    //     //var encoded = CBOR.encode(transaction);
    //     let sha = await generateSHA256(encoded);        
    //     console.log(sha)        

    //     let sha2 = await generateSHA256(encoded2);        
    //     console.log(sha2)        
        
    //     return;
    // }

}

export default PlugWallet