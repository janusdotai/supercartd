import { handleGlobalConnectionEvent, WalletProvider } from './index.js';
import { LOADING, removeBusy } from "../store/loader.js";
import { pushNotify } from '../store/utils.js';


class MetaMask {
    
    constructor(x){
        this.active_wallet = "";        
        this.web3 = null;
        this.status_msg = null;
        this.status = 0;
    }

    chainId(){
        return window.ethereum?.chainId;
    }

    async onInit() {                
        if(!document.getElementById("connection_status")){
            throw new Error("required element");
        }

        ethereum.on('accountsChanged', function (accounts) {
             if(accounts[0] == undefined || accounts.length == 0){
                this.status = -1;
                document.getElementById("connection_status").innerHTML = "User locked / Disconnected";
                return;
             }
             //console.log(accounts[0])
             document.getElementById("connection_status").innerHTML = accounts[0];
             this.status = 1;
             this.active_wallet = accounts[0];
        });

        ethereum.on('chainChanged', (chainId) => {
            // Handle the new chain.
            // Correctly handling chain changes can be complicated.
            // We recommend reloading the page unless you have good reason not to.
            //console.log("user changed chains..! " + chainId)
            document.getElementById("connection_status").innerHTML = "Meta Mask - user changed chains"
            document.getElementById("chain_status").innerHTML = chainId;         
            alert("BETA - sorry we have to reload for now when you switch chains")
            window.location.reload()
            return false;

        });

        document.getElementById("connection_status").innerHTML = "Meta Mask - Request permission"      
       
    }

    disconnect(){
        console.log('mm disconnect')
        this.active_wallet = "";
        this.web3 = null;
        this.status = 0;
        location.href = location.href;
    } 
    
    toString(){
        document.getElementById("connection_status").innerHTML = this.status_msg;
    } 

    async isUnlocked(){
        return await window.ethereum?._metamask.isUnlocked();
    }

    async getAccount() {                
        const accounts = window.ethereum.request({ method: 'eth_requestAccounts' }).then(x => {            
            if(!x || x == undefined){
                document.getElementById("connection_status").innerHTML = "Error - Please unlock Metamask";         
                return "";
            }
            var wallet = x[0];          
            this.active_wallet = wallet            
            window.web3 = new Web3(window.ethereum);
            this.web3 = window.web3;

            document.getElementById("connection_status").innerHTML = this.active_wallet;
            this.status_msg = this.active_wallet;

            const chainId = window.ethereum.chainId;
            document.getElementById("chain_status").innerHTML = chainId;
            //console.log(chainId);
            return this.active_wallet;
 
        }).catch((err) => {        
            //console.error(err);
            if (err.code === 4001) {
                // EIP-1193 userRejectedRequest error
                // If this happens, the user rejected the connection request.
                //console.log('Please connect to MetaMask.');
                document.getElementById("connection_status").innerHTML = "Error - Please check Metamask";
            }else if (err.code === -32002){
                document.getElementById("connection_status").innerHTML = err.message;
            } else {
                //console.error(err.message);
                document.getElementById("connection_status").innerHTML = JSON.stringify(err.code + err.message);
            }
            this.active_wallet = "";
            return "";
        });

        return accounts;
        
      
    }

    async personalSign(){        
        console.log("personal sign using wallet: " + this.active_wallet)
        try {
            const from = this.active_wallet;
            if(!from){
                alert("not connected!");
                return false;
            }
            var msg = "Sign this message to continue checkout:\n";
            msg += "Welcome from supercart!\n\n";            
            msg += new Date().toString();
            const sign = await ethereum.request({
                method: 'personal_sign',
                params: [
                    msg,                    
                    from,
                  ],
            });
           // console.log("signed result: " + sign)
            const recover_result = await web3.eth.personal.ecRecover(msg, sign).then(recover => {
                console.log("recover")
                console.log(recover);
                var match = recover.toLowerCase() === from.toLowerCase();
                if(!match){                    
                    console.log("EC RECOVER FAILED!")
                    document.getElementById("connection_status").innerHTML = "Error - Metamask EC Recover Failed";                    
                    throw new Error("EC Recover failed");
                }else{
                    document.getElementById("connection_status").innerHTML = "Metamask - Authenticated";                       
                    return true;            
                }
            });

            return recover_result;
         
        } catch ({name, message}) {
            console.log("personal sign error ")
            console.log(name)
            console.log(message)            
            document.getElementById("connection_status").innerHTML = `Error: ${message}`;
            return false;
        } 

    }   

    async proposeTransaction(provider, from, to, token_denomination, token_contract){
        if(provider !== WalletProvider.META_MASK){
            alert("Wrong provider")
            return false;
        }
        // console.log("plug proposeTransaction")
        // console.log("provider " + provider)
        // console.log("from " + from)
        // console.log("to " + to)   
        // console.log("token denomination " + token_denomination)
        // console.log("token_contract " + token_contract)
        if(from != this.active_wallet){
            pushNotify("error", "Meta Mask", "Error - User not connected");
            return false;
        }

        let fromAddr =  web3.utils.toChecksumAddress(this.active_wallet);                
        let toAmount = token_denomination;
        let toAddr = web3.utils.toChecksumAddress(to);
        //let chainId = parseInt(this.chainId, 16);
        let erc20abi = this.contractABI();
        const nonce = await web3.eth.getTransactionCount(fromAddr, 'latest');

        let rawTx = {};

        if (token_contract && token_contract != "") {  //erc20 send           
            console.log("ERC20 SEND") 
            let contract = new web3.eth.Contract(erc20abi, token_contract);
            let data = contract.methods.transfer(toAddr, toAmount).encodeABI();
            rawTx = {
                "from": fromAddr,
                "to": token_contract,
                "nonce": web3.utils.toHex(nonce),                
                "data": data,
            }
        } else {
            console.log("ETH SEND") 
            rawTx = {
                "from": fromAddr,
                "to": toAddr,
                "nonce": web3.utils.toHex(nonce),                
                "value": web3.utils.toHex(toAmount)
            }
        }

        try {
           
            const evm_tx = await web3.eth.sendTransaction(rawTx, function (error, hash) {
                LOADING.setLoading(true, "processing ... ");                
                if (error) {                                        
                    document.getElementById("connection_status").innerHTML = `Error: ${error.message}`;
                    if(error.code == 4001){                                                                   
                        //alert("User rejected the transaction, exiting");         
                        console.log(error)           
                        return;
                    }else{                        
                        console.log(error);                    
                        //alert(error.message);
                        return;
                    }
                  
                } else {
                    console.log("mm sendTransaction mempool...")
                    //console.log("here is the tx: " + hash)
                    pushNotify("info", "Meta Mask", "Confirming transaction - please wait", 8000);

                    var max = 80
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
                            LOADING.setLoading(true, "verifying please wait ... ");
                            if (err) {
                                console.log("getTransactionReceipt error")
                                console.log(err);
                            }

                            if (receipt && receipt.status == "1") {
                                clearInterval(interval);
                                LOADING.setLoading(true, "Confirmed!");
                                return receipt;

                            } else {
                                var loading_msg = "";
                                if (count == 0) {
                                    //app.update_progress(10);
                                    //pushNotify("info", "Meta Mask", "Confirming transaction - please wait");
                                } else if (count > 0 && count <= 2) {
                                    loading_msg = "...confirming transaction";
                                    //app.update_progress(20);
                                } else if (count > 2 && count <= 7) {
                                    loading_msg = "...getting confirmations " + count;
                                    //app.update_progress(40);
                                } else if (count > 7 && count <= 15) {                                
                                    loading_msg = "... confirming, please wait " + count;
                                    //app.update_progress(60);
                                } else if (count > 15 && count < 50) {                                
                                    loading_msg = "...network busy, hang on " + count;;
                                    //app.update_progress(80);
                                } else {                                                                
                                    loading_msg = "Error - process timeout";
                                    clearInterval(interval);                    
                                    //app.transaction_recovery();
                                }
                                LOADING.setLoading(true, loading_msg);                                
                            }
                        });
    
                    }, 3000);    
                }   
               
            });

            pushNotify("success", "Meta Mask", "Success!");
            let return_tx = { 
                "transactionHash": evm_tx.transactionHash.toString(), 
                "cumulativeGasUsed": evm_tx.cumulativeGasUsed.toString(), 
                "blockNumber" : evm_tx.blockNumber.toString() 
            };
            return return_tx;            

        } catch (e) {
            console.log("user rejected or error")
            console.log(e);         
            LOADING.setLoading(false, "");   
            throw e;         
        }        

    }
    

    contractABI(){
        let erc20abi = [            
            {
                'constant': false,
                'inputs': [
                    {
                        'name': '_to',
                        'type': 'address'
                    },
                    {
                        'name': '_value',
                        'type': 'uint256'
                    }
                ],
                'name': 'transfer',
                'outputs': [
                    {
                        'name': '',
                        'type': 'bool'
                    }
                ],
                'type': 'function'
            }
        ]
        return erc20abi;
    }
    
    weiToEth(weiBalance){
        let ethBalance = this.web3.utils.fromWei(weiBalance, 'ether');
        console.log(ethBalance);
        return weiBalance;
    }

};

export default MetaMask;

