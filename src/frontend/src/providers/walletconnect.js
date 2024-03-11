
import { WalletConnectModalSign } from "@walletconnect/modal-sign-html";
import { handleGlobalConnectionEvent, WalletProvider } from './index.js';
import { pushNotify, get_blockscan_url } from '../store/utils.js';


const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID;
if(!projectId){
    throw Error("invalid project id");
}

// 2. Create modal client
export const web3Modal = new WalletConnectModalSign({
    projectId,
    metadata: {
        name: "Supercartd",
        description: "Simple Checkouts",
        url: "https://supercart.ai",
        icons: [""]
    }
  });

class WalletConnect{   

    //signClient = null;
    //session = null;
    //web3 = null;
    //active_wallet = "";
    constructor(x){
        console.log("walletConnect constructor was called with arg: " + x);
        this.active_wallet = "";        
        this.web3 = null;
        this.status_msg = null;
        this.status = 0;
        this.chain_id = x;
        this.signClient = null;
        this.session = null;
        this.provider = "https://sepolia.publicgoods.network";
    }

    async onInit() {        
        console.log('wc oninit')
        //this.web3 = new Web3("https://eth-sepolia.g.alchemy.com/v2/demo")
        this.web3 = new Web3(this.provider);
        this.signClient = web3Modal
        if(this.signClient == null || this.signClient == undefined){
            throw Error("invalid signClient onInit")
        }
    }

    chainId(){
        return this.chain_id;
    }

    onInit(){
        console.log("wc init called");
        document.getElementById("connection_status").innerHTML = "Wallet Connect - Request permission init";
    }

    async disconnect(){
        console.log("wc wc disconnected");
    }   

    async isConnected(){
        return false;
    }

    async login(){
       

        // try{           
            
        //     const login_id = await this.handleConnect();            

        //     document.getElementById("chain_status").innerHTML = this.chainId();

        //     document.getElementById("connection_status").innerHTML = login_id;           

        //     this.handleAuthenticated(agent, session_id)
        //     pushNotify("success", "Wallet Connect", "Connected");

        //     return true;

        // }catch({name, message}){           
        //     //console.log(name)
        //     //console.log(message)
        //     if(message == "The agent creation was rejected."){
        //         document.getElementById("connection_status").innerHTML = "Plug - User rejected request"                
        //     }else{
        //         document.getElementById("connection_status").innerHTML = "Error - Plug wallet not found"
        //     }
        // }

        if(!this.signClient) throw Error("invalid signClient on walletconnect")
        console.log("trying to use walletconnect")

        try {

            const proposalNamespace = {
                eip155: {
                methods: ["eth_sendTransaction", "personal_sign"],
                chains: ["eip155:5"],
                events: ["connect", "disconnect", "accountsChanged", "chainChanged"],
                },
            };

           const session = await this.signClient.connect({
                requiredNamespaces: proposalNamespace,
            });
            console.log(session)

            if(!session){
                throw Error("could not establish wc session")
            }
            
            //await this.subscribeToEvents(session);           
            //const proposeTransactionButton = document.getElementById("btn_sendTransaction");
            //proposeTransactionButton.disabled = false;            
            const account_id = await this.onSessionConnected(session);
            return account_id;

        }catch(e){
            console.log(e);
        }
    }

    // async handleConnect() {   
    //     if(!this.signClient) throw Error("invalid signClient on walletconnect")

    //     try {

    //         const proposalNamespace = {
    //             eip155: {
    //             methods: ["eth_sendTransaction", "personal_sign"],
    //             chains: ["eip155:5"],
    //             events: ["connect", "disconnect", "accountsChanged", "chainChanged"],
    //             },
    //         };

    //        const session = await this.signClient.connect({
    //             requiredNamespaces: proposalNamespace,
    //         });
    //         console.log(session)

    //         if(!session){
    //             throw Error("could not establish wc session")
    //         }
            
    //         //await this.subscribeToEvents(session);           
    //         //const proposeTransactionButton = document.getElementById("btn_sendTransaction");
    //         //proposeTransactionButton.disabled = false;            
    //         const account_id = await this.onSessionConnected(session);
    //         return account_id;

    //     }catch(e){
    //         console.log(e);
    //     }
    // }     
    
    async subscribeToEvents(client) {
        if (!client){
            throw Error("Unable to subscribe to events. Client does not exist.");
        }
        try {
            client.on("session_delete", () => {
                console.log("The user has disconnected the session from their wallet.");
                this.reset();
            });

            client.on("session_event", (event) => {
                console.log("session event")
                console.log(event);        
            });
        
        }catch(e){
            console.log("subscribeToEvents exception...")
            console.log(e);
        }
    }

    reset(){
        this.signClient = null;
        this.web3 = null;     
        this.active_wallet = "";        
        console.log("client was reset");
        document.getElementById("connection_status").innerHTML = "Walletconnect (disconnected)";
    } 

    async onSessionConnected(session) {
        try {        
            console.log("onSessionConnected handler")
            //console.log(session)
            console.log(session.namespaces.eip155.accounts[0].slice(9));
            var accountId = session.namespaces.eip155.accounts[0].slice(9);

            this.active_wallet = accountId;
            this.session = session;
            document.getElementById("connection_status").innerHTML = "WalletConnect";

            return accountId;
            
        }catch(e){
            console.log(e);
        }
    }

    

    async disconnect() {
        try{            
            await this.signClient.disconnect({
                topic: this.session.topic,
                message: "User disconnected",
                code: 6000,
            });
            this.reset();
        }catch(e){
            console.log(e);
        }
    }

    async handleSend() {        
        
        if(!this.active_wallet){
            throw Error("No active wallet for walletconnect found")
        }

        try {
            const tx = {
                from: this.active_wallet,
                to: "",
                data: "0x",
                // gasPrice: "0x029104e28c",
                // gasLimit: "0x5208",
                value: "",
            };

            const result = await this.signClient.request({
                topic: this.session.topic,
                chainId: "eip155:5",
                request: {
                    method: "eth_sendTransaction",
                    params: [tx],
                }
            });
            
            console.log("transaction result:")
            console.log(result)
            //let tx_hash = result.hash;
            //console.log("TX HASH: " + tx_hash);
            await this.handleTransactionSentByClient(result);

        } catch (e) {
            console.log("user rejected or error")
            console.log(e);
            this.disconnect();
        }
    }

    async handleTransactionSentByClient(hash){
        if(!hash){
            alert("handleSend exception")
            return
        }

        console.log("checking the chain for this hash ... " + hash);    
        console.log("eth_getTransactionReceipt...starting verification loop");

        var max = 50
        var count = 0;

        const interval = setInterval(function () {                    
            count++;
            console.log("Attempting to get transaction receipt..." + count);
            if (count >= max) {
                clearInterval(interval);               
                alert("Max retries exceeded, exiting.");                
                return;
            }

            web3.eth.getTransactionReceipt(hash, function (err, receipt) {
                console.log("web3 getTransactionReceipt loop..." + count);

                if (err) {
                    console.log("getTransactionReceipt error")
                    console.log(err);
                }

                if (receipt && receipt.status == "1") {
                    clearInterval(interval);
                    var this_hash = receipt.transactionHash;
                      
                    console.log("TRANSACTION CONFIRMED!");
                    footer = "<h4 style='color: green;'><b>Transaction Confirmed!</b></h4>";
                    
                    var t = {"tx_hash": hash, "chain_id": 5};
                    var scan_url = get_blockscan_url(t);
                    footer += "<h4>" + scan_url + "</h4>";

                    document.getElementById("status").innerHTML = footer;

                } else {
                    var footer = "";
                    if (count == 0) {
                        //app.update_progress(10);
                    } else if (count > 0 && count <= 2) {
                        footer = "<h4>...confirming transaction</h4>";
                        //app.update_progress(20);
                    } else if (count > 2 && count <= 7) {
                        footer = "<h4>...confirming transaction " + count + "</h4>";
                        //app.update_progress(40);
                    } else if (count > 7 && count <= 15) {                                
                        footer = "<h4>... confirming, please wait " + count + "</h4>";
                        //app.update_progress(60);
                    } else if (count > 15 && count < 50) {                                
                        footer = "<h4 style='color: #F59B00;'>...network busy, hang on " + count + "</h4>";
                        //app.update_progress(80);
                    } else {                                                                
                        footer = "<h4 style='color: #FF2A00;'>" + count + " (TIMEOUT - recovery)</h4>";
                        clearInterval(interval);                               
                        //app.transaction_recovery();
                    }
                    document.getElementById("status").innerHTML = footer;                                  
                }
            });

        }, 4000); 

    }    
    
}

export default WalletConnect