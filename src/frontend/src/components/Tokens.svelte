<script>
import { onMount } from "svelte";
import { auth, user, token } from "../store/auth.js";
import { Link } from "svelte-routing";
import { LOADING, removeBusy } from "../store/loader.js";
import { timeAgoFromSecondEpoch, toDateFromSeconds, flatten, first, pushNotify } from "../store/utils.js"

$: tokens = [];
$: token_result_busy = false;

onMount(async () => {   
    LOADING.setLoading(true, "Loading tokens ....")
    await bind_tokens();    
    LOADING.setLoading(false, "")
});

async function bind_tokens(){    
    token_result_busy = true;
    const ignore = await $auth.actor.getTokensWithQuotes().then(x => {        
        var unsorted = x;
        unsorted.sort(function(a, b){
          return a.name.localeCompare(b.name);
        });
        tokens = unsorted;
        token_result_busy = false;
    }).catch(ex => {
      pushNotify("error", "Error", "Problem loading tokens from cache");
      throw ex;
    });
};

async function refreshTokenQuote(event, name, name_row_id, price_row_id, source_row_id, updated_row_id){    
    console.log("refreshing " + name);
    LOADING.setLoading(true, "LOADING ....");
    const things = document.querySelectorAll(".refresh-link").forEach(x => {      
      //console.log(x)
      if(event.target == x){
        //console.log("HEY WE FOUND HIM")
      }else{
        x.style.display = 'none';
      }
    });
    //console.log(things);
    let price_element = document.getElementById(price_row_id);
    if(!price_element){
      console.log("Error loading price_element cell");
      return false;
    }  
    let source_element = document.getElementById(source_row_id);
    if(!source_element){
      console.log("Error loading source_element cell");
      return false;
    }
    let updated_at_element = document.getElementById(updated_row_id);
    if(!updated_at_element){
      console.log("Error loading updated_at_element cell");
      return false;
    }

    event.target.setAttribute("aria-busy", "true");

    await $auth.actor.getTokenQuote(name).then(x => {
      //console.log(x);
      if(x.length != 1){
        console.log("problem with the getTokenQuote service");
        return;
      }

      var quote = x[0];
      //console.log(quote);
      //element.innerHTML = x;
      var ca = quote["created_at"];
      var name = quote["name"];
      var source = quote["source"];
      var symbol = quote["symbol"];
      var value = quote["value"];
      var value_str = quote["value_str"];
      //console.log(ca);
      var thing = toDateFromSeconds(ca);
      //console.log(thing);
      var friendlyTimeAgo = timeAgoFromSecondEpoch(thing);
      // console.log("name " + name);      
      // console.log("symbol " + symbol);
      // console.log("symbol " + source);      
      price_element.innerHTML = value_str;
      source_element.innerHTML = source;
      updated_at_element.innerHTML = friendlyTimeAgo;
      event.target.setAttribute("aria-busy", "false");   

      const things = document.querySelectorAll(".refresh-link").forEach(x => {      
      //console.log(x)
        if(event.target == x){
          //console.log("HEY WE FOUND HIM")
          x.style.display = 'Block';
        }else{
          x.style.display = 'Block';
        }
      });

      pushNotify("success", "Update", value_str);
      return true;

    }).catch(ex => {

      event.target.setAttribute("aria-busy", "false");
      price_element.innerHTML = "error";

      throw ex;
    });

    LOADING.setLoading(false, "");

};

function tokenIsTestnet(chains){
  //console.log(chains);
  var thing = chains.indexOf("testnet");
  const a = chains.every(chain => chain.includes("testnet"));
  //console.log(a)
  return a;
}


</script>

<section >
    <h1>Tokens</h1>       
</section>

<figure>
  <table>
    <thead>
      <tr>
        <th scope="col">Token</th>
        <th scope="col">Price</th>
        <th scope="col">Decimals</th>        
        <th scope="col">Chain</th>        
        <th scope="col">Provider</th>
        <th scope="col">Updated</th>
        <th scope="col">--</th>
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

            {@const first_chain = first(chains)}
            {@const flat_chains = flatten(chains)}

            {@const name_row_id = "token_update" + i + ""}
            {@const price_row_id = name + i + ""}
            {@const source_row_id = i + "source_row_update"}
            {@const updated_row_id = i + "updated_row_update"}     
            {@const recent_quote = entry["last_quote"][0] ?? null}       
            {@const last_quote =  entry["last_quote"][0] ?? {"value_str": "0.00" } }
            {@const symbol = "$" }
            {@const is_testnet = tokenIsTestnet(flat_chains)}
            {@const updated_at = last_quote["created_at"] ?? created_at}
            {@const updated_at_friendly = new toDateFromSeconds(updated_at)}
            
                <tr>
                  <td>                    
                    <Link to="/tokens/{slug}"><img src="{image_url}" alt="" class="token-icon" />{name}</Link>
                  </td>                
                <td id={price_row_id}>                
                  {symbol}{last_quote.value_str}
                </td>
                <td>{decimals}</td>           
                <td>
                  {#if (is_testnet)}
                  <em data-tooltip="{flat_chains}"><span class="">{first_chain}</span></em>
                  {:else}
                  <em data-tooltip="{flat_chains}"><span class="pico-color-green-500">{first_chain}</span></em>
                  {/if}

                </td>
                <td id={source_row_id}>
                  {#if (recent_quote)}
                    <span>cache</span>
                  {:else}
                    <span></span>
                  {/if}
                  
                </td>

                <td id={updated_row_id} title={updated_at_friendly}>{timeAgoFromSecondEpoch(updated_at)}</td>

                <td id={name_row_id}>
                  {#if ($auth.loggedIn)}
                      <!-- svelte-ignore a11y-invalid-attribute -->            
                      <a href="#" class="refresh-link" on:click|preventDefault={event => refreshTokenQuote(event, name, name_row_id, price_row_id, source_row_id, updated_row_id)}>refresh</a>
                  {:else}
                    <span></span>
                  {/if}
                </td>                
            </tr>
            
        {/each}
      {/if}
    </tbody> 
  </table>
</figure>
<section>
  <center><Link to="/currencies" >View Currencies</Link></center>
</section>
<style>
  .token-icon{
      width: 16px;
      height: 16px;
      vertical-align:auto;
  }
</style>