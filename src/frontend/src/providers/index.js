

const WalletProvider = {
  WALLET_CONNECT: 1,
  META_MASK: 2,
  INTERNET_IDENTITY: 3,
  PLUG_WALLET: 4,
  PHANTOM_WALLET: 5
}

export function WalletProviderToString(numericValue) {
  for (const key in WalletProvider) {
    if (WalletProvider[key] === numericValue) {
      return key;
    }
  }
  return null; // Return null if no matching string value is found
}

// public type TokenChain = {
//   #btc_mainnet;
//   #icp_mainnet;
//   #icp_testnet;
//   #eth_mainnet;
//   #eth_testnet;
//   #sol_mainnet;
//   #tao_mainnet;
//   #op_mainnet;
//   #arb_mainnet;
//   #base_mainnet;
//   #ftm_mainnet;
//   #bsc_mainnet;
// };

export function ChainIdToTokenChain(sc_provider){
  if(!sc_provider) return "Invalid chain_id";
 // console.log("ChainIdToPubChain : " + sc_provider);
  switch(sc_provider.toLowerCase()){
    case "internet computer":
      return "icp_mainnet";
    case "sol_mainnet":
      return "sol_mainnet";
    case "0x1":
      return "eth_mainnet";
    case "0x5":
      throw new Error("goerli is no longer supported");
    case "0xaa36a7":
      return "eth_testnet";    
    default:
      return null;
  }

}

// CHAIN METHODS
async function handleGlobalDisconnect(account, session, provider){
  console.log(provider)
  document.getElementById("provider_status").innerHTML = "";
  switch(provider){
    case 1:
      console.log("handleGlobalDisconnect WALLET_CONNECT")
      wcClient.disconnect()
      break;
    case 2:
      console.log("handleGlobalDisconnect META_MASK")
      await mmClient.disconnect()
      break;
    case 3:
      console.log("handleGlobalDisconnect INTERNET_COMPUTER")
      break;
    case 4:
      console.log("handleGlobalDisconnect PLUG_WALLET")  
      await plugClient.disconnect()
      break;
    default:
      console.log("INVALID PROVIDER")
      throw Error("Invalid Provider");
      break;
  }

}

async function handleGlobalConnectionEvent(account, session, provider){
 
  console.log("handleGlobalConnectionEvent")
  console.log("account " + account)
  console.log("session " + session)
  console.log("provider " + provider)
}




export { handleGlobalConnectionEvent, WalletProvider };
