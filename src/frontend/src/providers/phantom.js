import { handleGlobalConnectionEvent, WalletProvider } from './index.js';
import { LOADING, removeBusy } from "../store/loader.js";
import * as solanaWeb3 from "@solana/web3.js";
import { pushNotify } from "../store/utils.js";

const VITE_ALCHEMY_SOL_KEY = import.meta.env.VITE_ALCHEMY_SOL_KEY;
class PhantomWallet {   

    constructor(x){        
        this.active_wallet = "";        
        this.status_msg = null;
        this.status = 0;     
        this.chain_id = x || "sol_mainnet";
        this.alchemy_key = VITE_ALCHEMY_SOL_KEY;
    }

    onInit(){
        console.log("phantom init called")        
    }

    getProvider(){
        console.log("fetching provider..")
        if('phantom' in window){
            const provider = window.phantom?.solana;      
            if(provider?.isPhantom){
                return provider;
            }
        }
        return null;
    }

    async login(){        
        const provider = this.getProvider();
        try{
            const resp = await provider.connect();
            const pubkey = resp.publicKey.toString();            
            this.active_wallet = pubkey;
            document.getElementById("connection_status").innerHTML = this.active_wallet; 
            const s = await this.personalSign().then(x => {
                if(x === true){
                    return true;
                }else{
                    return false;
                }
            })
            return s;
        }catch(err){
            // { code: 4001, message: 'User rejected the request.' }
            console.log(err)
            console.log(err.code)
            console.log(err.message)
            this.active_wallet = "";
            return false;
        }        
    }

    async personalSign(){
        try{
            const provider = this.getProvider();           
            var msg = "Sign this message to continue checkout:\n";
            msg += "Welcome from supercart!\n\n";            
            msg += new Date().toString();

            const encodedMessage = new TextEncoder().encode(msg);
            const signedMessage = await provider.signMessage(encodedMessage, "utf8");
            //console.log(signedMessage);
            //TODO: recover?

            return true;

        }catch(err){
            throw err;            
        }
    }

   
    //https://github.com/extrnode/rpc-solana-endpoints
    //https://stackoverflow.com/questions/68166964/how-can-you-transfer-sol-using-the-web3-js-sdk-for-solana
    async transferSOL(from, to, token_denomination) {       

        // Detecing and storing the phantom wallet of the user (creator in this case)
        var provider = await this.getProvider();
        let sol_rpc = "https://solana-mainnet.g.alchemy.com/v2/" + this.alchemy_key;
        // Establishing connection
        var connection = new solanaWeb3.Connection(
            sol_rpc
        );
        
        var senderWallet = new solanaWeb3.PublicKey(from);
        var recieverWallet = new solanaWeb3.PublicKey(to);
        var transaction = new solanaWeb3.Transaction().add(
            solanaWeb3.SystemProgram.transfer({
                //fromPubkey: provider.publicKey,
                fromPubkey: senderWallet,
                toPubkey: recieverWallet,
                lamports: token_denomination
                //lamports: solanaWeb3.LAMPORTS_PER_SOL //Investing 1 SOL. Remember 1 Lamport = 10^-9 SOL.
            })
        );

        // Setting the variables for the transaction
        transaction.feePayer = await provider.publicKey;
        let blockhashObj = await connection.getLatestBlockhash();
        transaction.recentBlockhash = blockhashObj.blockhash;           
    
        // Request creator to sign the transaction (allow the transaction)
        let signed = await provider.signTransaction(transaction);
        // The signature is generated
        let signature = await connection.sendRawTransaction(signed.serialize());        
        let pkg2 = { signature: signature };
        LOADING.setLoading(true, "Sending transaction please wait ... ");
        pushNotify("info", "Phantom", "Sending transaction please wait", 8000)
        console.log(pkg2)

        let sol_tx = await connection.confirmTransaction(pkg2);
        sol_tx["sig"] = signature;
        console.log("sol_tx: ", sol_tx);
        
        return sol_tx;
    }
    

    async proposeTransaction(provider, from, to, token_denomination, token_contract){
        if(provider !== WalletProvider.PHANTOM_WALLET){
            alert("Wrong provider")
            return false;
        }
        if(!this.alchemy_key){
            alert("Alchemy key not found")
            return false;
        }             
        
        try{           
            const provider = this.getProvider();
            console.log("provider is " + provider)         
            if(provider == null){
                throw new Error("Phantom wallet not found");
            }
            if(!this.alchemy_key || this.alchemy_key.length < 10){
                throw new Error("Alchemy key not found");
            }
            
            const tx_result = await this.transferSOL(from, to, token_denomination);
            console.log(tx_result) 

            let slot = tx_result.context.slot.toString();
            let hash = tx_result.sig.toString();
            let return_tx = { "transactionHash": hash, "cumulativeGasUsed": "", "blockNumber": slot };
            LOADING.setLoading(false, "Success!");
            pushNotify("success", "Phantom", "<b>Success!</b>")
            return return_tx;
        }catch(ex){
            console.log(ex)            
            document.getElementById("connection_status").innerHTML = ex?.message;
            document.querySelector(".connection_status").innerHTML = ex?.message;
            document.querySelectorAll(".connection_status").forEach(x => {
                x.classList.add("pico-color-red-500");
            });
            LOADING.setLoading(false, "");         
        }
        return "";
    }
    

    async handleAuthenticated(authClient){
       
    }

    async disconnect(){
        console.log("phantom was disconnected")
        const provider = this.getProvider();
        if(provider){
            provider.disconnect();
        }
    }

}

export default PhantomWallet