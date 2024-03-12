
<script>
import { Link, navigate } from "svelte-routing";
import { onMount, afterUpdate, onDestroy } from "svelte";
import { auth, user, token } from "../store/auth.js";
import { LOADING, removeBusy } from "../store/loader.js";
import { timeAgoFromSecondEpoch, timeAgoFromEpoch, flatten, key2val, first } from "../store/utils.js"

$: tokens = [];
$: token_result_busy = false;

let payment_settings = [];

let IS_LOADING;
const unsubscribe = LOADING.subscribe((value) => {
    IS_LOADING = value["status"] == "IDLE" ? false : true;
});
onDestroy(unsubscribe);

onMount(async () =>{

    if($auth.loggedIn){        
        LOADING.setLoading(true, "LOADING ....");       
        await load_payment_settings();
        //await load_chains();
        await load_tokens();
        LOADING.setLoading(false, "done! ....")
    }else{
        console.log("..skipping loading pts")
        alert("WOOPS? Not logged in ... ");
        navigate("/");
    }
})

async function load_tokens(){    
    token_result_busy = true;  
    const ignore = await $auth.actor.getTokensWithQuotes().then(x => {        
        let unsorted = x;        
        unsorted.sort(function(a, b){
          return a.name.localeCompare(b.name);
        });        
        tokens = unsorted;
        token_result_busy = false;
    });
};


async function load_payment_settings() {
    const payments2 = await $auth.actor.getPaymentSettings().then(z => {      
      payment_settings = z[0];      
    });
}

async function load_chains(){
  const chains = await $auth.actor.getChains().then(x =>{
    console.log(x)
  });
}

  
function goBack(){
  navigate("/admin", false);
}  


function is_setting_enabled(token_type, chain){  
  var tt = key2val(token_type);  
  var match = payment_settings.find(y => key2val(y.token_type) == tt &&  key2val(y.chain) == chain);  
  if(!match) return false;

  var enabled = match["is_enabled"] == true ? true : false;
  return enabled;  
}

function last_setting_update_time(token_type){
  var tt = key2val(token_type);  
  var match = payment_settings.find(y => key2val(y.token_type) == tt);  
  if(match){
    var ua = match["updated_at"];
    return ua;
  }else{
    return 0;
  }
}

function tokenIsTestnet(chains){  
  var thing = chains.indexOf("testnet");
  const a = chains.every(chain => chain.includes("testnet"));  
  return a;
}


</script>

<nav aria-label="breadcrumb">
    <ul>
      <li><Link to="/" title="Home">Home</Link></li>
      <li>
        <Link to="/admin" title="Admin">Admin</Link>
      </li>
      <li>Payments</li>
    </ul>
</nav>

<h2>Payment / Token Setup</h2>
<article>
  <p>Instructions: <code>For each payment method you want to accept, enable it and add your public wallet address</code></p>
  <p>Be extra cautious when adding your public wallet address.<br>Please ensure its correct for the chain you are enabling!</p>
</article>
<figure>
    <table>
      <thead>
        <tr>
          <th scope="col">Token</th>
          <th scope="col">Chain</th>
          <th scope="col">Enabled</th>
          <th scope="col">Accepting</th>        
          <th scope="col">Updated</th>
        </tr>
      </thead>
      <tbody>
        {#if tokens.length > 0}
          {#each tokens as entry, i}
  
              {@const created_at = entry["created_at"]}
              {@const name = entry["name"]}
              {@const decimals = entry["decimals"]}
              {@const abi = entry["abi"]}
              {@const chains = entry["chains"]}
              {@const slug = entry["slug"]}
              {@const image_url = "/images/tokens/" + slug + ".png".toLowerCase() }
              {@const token_type = entry["token_type"] }
  
              {@const first_chain = first(chains)}
              {@const flat_chains = flatten(chains)}  
              
              {@const test = tokenIsTestnet(flat_chains)}
              {@const setting_is_enabled = is_setting_enabled(token_type, first_chain)}

              {@const setting_last_updated = last_setting_update_time(token_type)}              
                  <tr>
                    <td>
                      {#if (test)}
                      <Link to="/store/payments/edit/{slug}"><img src="{image_url}" alt="" class="token-icon" /> {name} </Link>
                      {:else}
                      <Link to="/store/payments/edit/{slug}"><img src="{image_url}" alt="" class="token-icon" /> {name} </Link>
                      {/if}
                    </td>                
                    <td>
                        <em data-tooltip="{flat_chains}">{first_chain}</em>
                    </td>
                  <td>
                    {#if (setting_is_enabled)}
                     <code class="pico-color-green-250">yes</code>
                    {:else}
                      <code>no</code>
                    {/if}
                  </td>           
                  <td>
                    <code>No</code>
                  </td>
                  <td >
                    {#if (setting_last_updated > 0)}
                      {timeAgoFromSecondEpoch(setting_last_updated)}
                    {:else}
                      <span>Not set</span>
                    {/if}
                  </td> 
              </tr>              
          {/each}
        {/if}
      </tbody>      
    </table>
  </figure>
  <section>    
    <p>
      <button class="secondary" on:click={goBack}>Back</button>
    </p>
  </section>
  <style>
    .token-icon{
        width: 16px;
        height: 16px;
        vertical-align:auto;
    }
  </style>