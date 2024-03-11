
export function toDateFromSecondsSafe(seconds_since_epoch){  
  try{
    const s = Number(seconds_since_epoch);
    const ms = s * 1000;
    const dateObject = new Date(ms);
    //console.log(dateObject);
    return dateObject;
  }catch(err){
    console.log(seconds_since_epoch)
    console.log(err)
    return new Date();
  } 
}

export function toDateFromMiliSeconds(ms_since_epoch){      
  const ms = ms_since_epoch;
  const dateObject = new Date(ms);    
  return dateObject;
}

export function toDateFromSeconds(seconds_since_epoch){    
    const s = Number(seconds_since_epoch);
    const ms = s * 1000;
    const dateObject = new Date(ms);    
    return dateObject;
}

// export function toDateFromNanoSeconds(ns_since_epoch){
//   const s = BigInteger(ns_since_epoch);
//   const ms = s * 1000000;
//   const dateObject = new Date(ms);  
//   return dateObject  
// }

export function getTimestampEpoch() {
    const unixTimestampInSeconds = Math.floor(Date.now() / 1000);
    return Number(unixTimestampInSeconds);
}

export function timeAgoFromEpoch(nanoseconds_since_epoch){
    let milliseconds = Number(nanoseconds_since_epoch) * 1000; // epoch date
    let date = new Date(milliseconds);
    //console.log(date);
    return timeAgo(date);
}

export function timeAgoFromSecondEpoch(seconds_since_epoch){
  //console.log(seconds_since_epoch)
  let milliseconds = Number(seconds_since_epoch) * Number(1000);
  let date = new Date(milliseconds);
  //console.log(date);
  let ta = timeAgo(date);
  //console.log(ta);
  return ta;
}

export function timeAgo(date) {
    if(!date || date === undefined){
        return "Invalid date";
    }
    if(date == "Invalid Date"){      
      return "Invalid date";
    }

    const now = new Date();
    const timeDifference = now - date;
    const seconds = Math.floor(timeDifference / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    const weeks = Math.floor(days / 7);   
  
    if (weeks > 0) {
      return weeks === 1 ? '1 week ago' : `${weeks} weeks ago`;
    } else if (days > 0) {
      return days === 1 ? '1 day ago' : `${days} days ago`;
    } else if (hours > 0) {
      return hours === 1 ? '1 hour ago' : `${hours} hours ago`;
    } else if (minutes === 1) {
      return `${minutes} minute ago`;
    } else if (minutes > 1 && minutes < 10) {
      return `${minutes} minutes ago`;
    } else if (minutes > 0) {
        return `${minutes} minutes ago`;
    } else if (seconds > 0) {
      return `${seconds} seconds ago`;    
    } else {
      //console.log("default trap timeAgo " + date + ":" + weeks)
      return 'Just now';
    }

}


async function sha224(principal, subaccount) {  
  data = ["\x0Aaccount-id", principal.toUint8Array(), subaccount ? subaccount : new Uint8Array(32)]
  const uint8Array = new TextEncoder().encode(data)
  SubtleCrypto.digest("SHA-256", uint8Array)
  return uint8Array
}

//https://github.com/ninegua/tipjar/blob/main/src/tipjar_assets/src/agent.js#L2
function principalToAccountId(principal, subaccount) {
  const hash = sha224(principal, subaccount);
  const crc = crc32.buf(hash);
  return [
    (crc >> 24) & 0xff,
    (crc >> 16) & 0xff,
    (crc >> 8) & 0xff,
    crc & 0xff,
    ...hash,
  ];
}

function toHexString(byteArray) {
  return Array.from(byteArray, function(byte) {
    return ('0' + (byte & 0xFF).toString(16)).slice(-2);
  }).join('')
}

export function getAccountIdFromPrincipal(principal){
  var p = principalToAccountId(principal);
  return toHexString(p);
}


export async function generateSHA256(input) {
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(byte => byte.toString(16).padStart(2, '0')).join('');
  return hashHex;
}


export async function generateRandomSHA256(length) {
  // Generate random bytes
  if(length < 256) throw Error;
  const randomBytes = new Uint8Array(length);
  crypto.getRandomValues(randomBytes);
  // Convert random bytes to ArrayBuffer
  const buffer = randomBytes.buffer;
  // Hash the buffer using SHA-256
  const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
  // Convert hash buffer to hex string
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(byte => byte.toString(16).padStart(2, '0')).join('');
  return hashHex;
}


export function flatten(thing){
  //{"propertname": null}, {"propertyname2", null}  ==> ["propertyname", "propertyname2"]
  return thing.flatMap(obj => Object.keys(obj));
}

export function first(thing){
  //{"propertname": null}, {"propertyname2", null}  ==> "propertyname"
  return thing.flatMap(obj => Object.keys(obj))[0];
};

//transform : { ckbtc: null } = ckbtc
export function key2val(thing){
  // Get the keys of the object
  const keys = Object.keys(thing);  
  // Assuming you want the first key
  const firstKey = keys[0];  
  return firstKey;
}

export function ellipsis(s, n){
  if(!s) return "...";
  return s.slice(0, n) + "...";
}

export function transformTokenHistory(history){
  //make tradingview friendly
  //input = [{ value: 25222525.1, created_at: 1642425322 }, { value: 8, created_at: 1642511722 }]
  //const data = [{ value: 1, time: 1642425322 }, { value: 8, time: 1642511722 }    
  var result = [];
  history.forEach(function(thing){
    //console.log(thing);
    var dt = thing["created_at"]; //seconds since epoch
    var dts = Number(dt);
    var v = thing["value"] || 0.00;
    var t = {value: v, time: dts};
    result.push(t);
  });
  //console.log(result);  
  //tv wants asc by date
  result.sort(function(a, b) {
    return a.time - b.time;
  });

  return result;
}

export function transformOrderHistory(history){  
  //make tradingview friendly
  //input = [{ value: 25222525.1, created_at: 1642425322 }, { value: 8, created_at: 1642511722 }]
  //const data = [{ value: 1, time: 1642425322 }, { value: 8, time: 1642511722 }    
  var result = [];
  history.forEach(function(thing){
    //console.log(thing);
    var dt = thing["created_at"]; //seconds since epoch
    var dts = Number(dt);
    var v = thing["grand_total"] || 0.00;
    var t = {value: v, time: dts};
    result.push(t);
  });
  //console.log(result);  
  //tv wants asc by date
  result.sort(function(a, b) {
    return a.time - b.time;
  });

  return result;
}

export function getUrlParams() {
  const searchParams = new URLSearchParams(window.location.search);
  const params = {};
  for (const [key, value] of searchParams.entries()) {
    params[key] = value;
  }
  return params;
};


export function get_blockscan_url(transaction, truncate = true) {
  var link_target = "#";
  //console.log(transaction)
  switch (transaction.sc_chain.toLowerCase()) {
      case "eth_mainnet":
          link_target = "https://etherscan.io/tx/" + transaction.tx_hash;            
          break;
      case "eth_testnet":
          link_target = "https://sepolia.etherscan.io/tx/" + transaction.tx_hash;
          break;
      case "op_mainnet":
          link_target = "https://optimistic.etherscan.io/tx/" + transaction.tx_hash;
          break;
      case "bsc_mainnet":
          link_target = "https://bscscan.com/tx/" + transaction.tx_hash;
          break;
      case "ftm_mainnet":
          link_target = "https://ftmscan.com/tx/" + transaction.tx_hash;
          break;
      case "arb_mainnet":
          link_target = "https://arbiscan.io/tx/" + transaction.tx_hash;
          break;
      case "icp_mainnet":
          link_target = "https://dashboard.internetcomputer.org/transaction/" + transaction.tx_hash + "?index=" + transaction.block_height;
          break;
      case "sol_mainnet":
          link_target = "https://explorer.solana.com/tx/" + transaction.tx_hash;
          break;
      default:
          return "<div><a href=\"#\">Invalid chain</a></div>";          
  }  
  
  var addr = transaction.tx_hash;
  if(truncate){
    addr = ellipsis(transaction.tx_hash, 10);
  }

  var link = "<span>";
  link += " <a href='" + link_target + "' target='_new' >" + addr + "</a>";
  link += "</span>";
  return link;
}

export function debounce(func, wait, immediate) {
  var timeout;
	return function() {
		var context = this,
    args = arguments;
		var later = function() {
			timeout = null;
			if(!immediate){
				func.apply(context, args);
			}
		};
		var callNow = immediate && !timeout;
		clearTimeout(timeout);
		timeout = setTimeout(later, wait);
		if(callNow){
			func.apply(context, args);
		}
	};
}

export function pushNotify(status, title, text, autotimeout = 3000) {
  if(!status || !title || !text){
      alert("problem with notification")
      return;
  }  
  text = stripHtmlTags(text);
  try{
    new Notify({
      status: status,
      title: title,
      text: "<b>" + text + "</b>", 
      autotimeout: autotimeout,
      type: 'filled'
    })
  }catch{
    console.log("problem with pushNotify");
  }  
}

export function stripHtmlTags(input){
  const tempElement = document.createElement("div");
  tempElement.innerHTML = input;    
  // Get the text content (without HTML tags)
  return tempElement.textContent || tempElement.innerText || "";
}
