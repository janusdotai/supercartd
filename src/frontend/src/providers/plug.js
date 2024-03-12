
import { handleGlobalConnectionEvent, WalletProvider } from './index.js';
import { getAccountIdFromPrincipal, key2val,  pushNotify, ellipsis } from "../store/utils.js"
import { LOADING } from "../store/loader.js";
import ic from 'ic0';

const LEDGER_ID = "ockk2-xaaaa-aaaai-aaaua-cai"
const NATIVE_ICP = "ryjl3-tyaaa-aaaaa-aaaba-cai";

class PlugWallet{   

    constructor(x){        
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
            var agent = window.ic.plug.agent;
            var plug_principal_id = window.ic.plug.principalId ?? "unknown"
           
            this.active_wallet = plug_principal_id;
            this.chain_id = "Internet Computer"

            document.getElementById("chain_status").innerHTML = this.chainId();

            this.handleAuthenticated(agent, plug_principal_id)
            pushNotify("success", "Plug Wallet", "Connected");
            return true;
        }catch({name, message}){                       
            if(message == "The agent creation was rejected."){
                document.getElementById("connection_status").innerHTML = "Plug - User rejected request"                
            }else{
                document.getElementById("connection_status").innerHTML = "Error - Plug wallet not found"
            }
        }
    }

    async handleAuthenticated(authClient, principalId){        
        let p = ellipsis(principalId, 12);
        document.getElementById("connection_status").innerHTML = p;
    }   

    async proposeTransaction(provider, from, to, token_denomination, token_contract){
        if(provider !== WalletProvider.PLUG_WALLET){
            alert("Wrong provider")
            return false;
        }
        
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
                pushNotify("info", "Plug Wallet", "Confirming block " + block );                
                
                //TODO: move this to server side
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
            document.getElementById("connection_status").innerHTML = message;
            document.querySelector(".connection_status").innerHTML = message;
            document.querySelectorAll(".connection_status").forEach(x => {
                x.classList.add("pico-color-red-500");
            });        
            LOADING.setLoading(false, "");
        }
        return 0;
    }

    //fetches a block on the client side
    async validateTransaction(block){
        console.log("validating block " + block)        
        const ledger = ic(LEDGER_ID);
        try{
            const thing = await ledger.call('block', block);
            var transaction = thing?.Ok?.Ok?.transaction;
            if(!transaction){
                return { "result": false, "tx": "" };
            };
            let tx_hash = block;
            var transfer = transaction?.transfer;
            var send = transfer?.Send;
            var amount = send.amount;
            var from = send.from;
            var to = send.to;
            var e8s = key2val(amount);
            //console.log(`parsed block for amount ${e8s} send from ${from} to ${to}`)
            //console.log(`tx ${tx_hash}`)
            return { "result": true, "tx": tx_hash, "block": block };
        }catch(e){
            console.log(e)
            pushNotify("error", "Plug Wallet", "Error validating transaction")            
        }
        return { "result": false, "tx": "" };
    }

}

export default PlugWallet