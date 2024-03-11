import { handleGlobalConnectionEvent, WalletProvider } from './index.js';
import MetaMask from "./metamask.js";
import PlugWallet from "./plug.js";
import PhantomWallet from "./phantom.js";

class TransactionProvider {   

    constructor(chainId){
        console.log("TransactionProvider constructor was called w " + chainId)
        this.active_wallet = "";        
        this.status_msg = null;
        this.status = 0;
        this.chain_id = chainId;
    }

    onInit(){
        console.log("TransactionProvider init called")
    }
    
    // const WalletProvider = {
    //   WALLET_CONNECT: 1,
    //   META_MASK: 2,
    //   INTERNET_IDENTITY: 3,
    //   PLUG_WALLET: 4,
    //   PHANTOM_WALLET: 5
    // }

    //old sc way
    //const trans = app.create_transaction(addr, dwallet, token_denomination, token_contract, currency_chain_id);  
    async proposeTransaction(provider, from, to, token_denomination, token_contract){
        switch(provider){
            case 1:
                break;
            case 2:
                return await this.metamaskTransaction(provider, from, to, token_denomination, token_contract);
            case 3:
                break;
            case 4:
                return await this.plugTransaction(provider, from, to, token_denomination, token_contract);
            case 5:
                return await this.phantomTransaction(provider, from, to, token_denomination, token_contract);
            default:
                console.log(provider);
                throw new Error("invalid transaction provider");
        }
    }

    async plugTransaction(provider, from, to, token_denomination, token_contract){
        console.log("Plug about to propose ")
        const plugClient = new PlugWallet(this.chain_id)
        plugClient.active_wallet = from;
        plugClient.onInit();
        var tx = await plugClient.proposeTransaction(provider, from, to, token_denomination, token_contract);
        return tx;
    }

    async metamaskTransaction(provider, from, to, token_denomination, token_contract){
        console.log("Metamask about to propose ")
        const mmClient = new MetaMask(this.chain_id)
        mmClient.active_wallet = from;
        mmClient.onInit();
        var tx = await mmClient.proposeTransaction(provider, from, to, token_denomination, token_contract);
        return tx;
    }

    async phantomTransaction(provider, from, to, token_denomination, token_contract){
        console.log("Phantom about to propose ")
        const phClient = new PhantomWallet(this.chain_id)
        phClient.active_wallet = from;
        phClient.onInit();
        var tx = await phClient.proposeTransaction(provider, from, to, token_denomination, token_contract);
        return tx;
    }

}

export default TransactionProvider