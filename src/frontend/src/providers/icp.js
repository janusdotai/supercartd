import { AuthClient } from "@dfinity/auth-client";
import { handleGlobalConnectionEvent, WalletProvider } from './index.js';


class InternetComputer{

    active_wallet = ""

    constructor(x){
        console.log("icp constructor was called ")        
    }

    onInit(){
        console.log("icp init called")
        
    }

    async login(){
        const authClient = await AuthClient.create();
        authClient.login({
            // 7 days in nanoseconds
            maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000),
            onSuccess: async () => {
              await this.handleAuthenticated(authClient);
            },
            onError: async(err) => {
                console.log("ICP login error ")
                console.log(err)
            }
          });
    }

    async handleAuthenticated(authClient){
        console.log("icp handleAuthenticated ")
        console.log("authClient")
        console.log(authClient)

        const identity = await authClient.getIdentity();
        console.log("identity")
        console.log(identity)
        
        const principal = identity.getPrincipal();
        console.log('principal')
        console.log(principal)
        const principalId = principal.toString();
        console.log(principalId)

        const pub = identity.getPublicKey();
        console.log('pub key')
        console.log(pub)

        document.getElementById("connection_status").innerHTML = "ICP - Authenticated";

        handleGlobalConnectionEvent(principalId, authClient, WalletProvider.INTERNET_IDENTITY);
        //handleGlobalConnectionEvent()
    }

    async disconnect(){
        console.log("icp was disconnected")


    }


}

export default InternetComputer