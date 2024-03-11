<script>
    import { onMount, afterUpdate } from "svelte";
    import { auth, user, token } from "../store/auth.js";
    import { Link, navigate } from "svelte-routing";
    import { getTimestampEpoch, timeAgoFromEpoch, generateRandomSHA256, ellipsis, first, flatten, stripHtmlTags, pushNotify } from "../store/utils.js"
    import { LOADING, removeBusy } from "../store/loader.js";

    export let slug = ""; //token slug    

    let cid;
    let is_insert = true;
    let is_enabled = false;
    let created_at;
    let updated_at;
    let dest;   
    let guid;

    let token_name;
    let token_image_url;
    let token_description;
    let token_chain;
    let token_chain_tooltip = "Chain tooltip here";
   
    const chain_mapping = [

        {"name" : "btc_mainnet", "code" : "#btc_mainnet", "info": ""},
        {"name" : "eth_mainnet", "code" : "#eth_mainnet", "info": ""},
        {"name" : "eth_testnet", "code" : "#eth_testnet", "info": ""},
        {"name" : "icp_mainnet", "code" : "#icp_mainnet", "info": ""},
        {"name" : "icp_testnet", "code" : "#icp_testnet", "info": ""},
        {"name" : "op_mainnet", "code" : "#op_mainnet", "info": ""},
        {"name" : "arb_mainnet", "code" : "#arb_mainnet", "info": ""},
        {"name" : "base_mainnet", "code" : "#base_mainnet", "info": ""},
        {"name" : "sol_mainnet", "code" : "#sol_mainnet", "info": ""}

    ];

    onMount(async () => {        
       // console.log("slug : " + slug); 
        //console.log("PAYMEND EDIT loaded checkout  id : " + cid);
        if(!slug || slug.length < 3){
            alert("There was an error loading this payment")
            navigate("/store/payments");
            return;
        };
        LOADING.setLoading(true, "Loading settings ... ");
        await bind_token_info();
        await bind_payment_setting();
    });

    async function bind_token_info(){
        const tokens = $auth.actor.getTokens().then(x => {
            //console.log(x);
            const match = x.find(s => s.slug.toUpperCase() == slug.toUpperCase());
            //console.log(match)
            if(match){                
                token_name = match["name"]
                token_image_url = "/images/tokens/" + slug + ".png".toLowerCase();
                token_description = match["description"];
                
                var chain_list = match["chains"] || [];                
                if(chain_list.length === 0){
                    alert("Invalid token chain setup")
                    navigate("/store/payments");
                }else if(chain_list.length != 1){
                    alert("You are configuring an invalid token!")
                    navigate("/store/payments");
                };

                var first_chain = first(chain_list);
                token_chain = first_chain;                
                var local_match = chain_mapping.find(x => x.name === token_chain);
                //console.log(local_match);
                if(!local_match){
                    alert("You are configuring an invalid token!")
                    navigate("/store/payments");
                };
                

            }else{
                alert("Error, invalid token slug!")
                throw "Invalid Slug";
            }
        })
    }

    async function bind_payment_setting(){
        if(!slug){
            console.log("invalid slug")
            navigate("/admin");
            return;
        }
        const ps = $auth.actor.getPaymentSetting(slug).then(x => {
            //console.log(" loading payment setting: " + slug)
            //console.log(x)            
            is_insert = x.length == 0 ? true : false;
            //console.log("Is insert? " + is_insert);

            if(!is_insert){
               // console.log("Updating Record")
                var setting = x[0];
                //console.log(setting)
                is_enabled = setting["is_enabled"];
                created_at = setting["created_at"];
                updated_at = setting["updated_at"];
                dest = setting["dest"];
                dest = stripHtmlTags(dest);
                guid = setting["guid"];

            }else{
                console.log("no existing records found for : " + slug)
                console.log("Inserting Record")
                1==1
            }
            LOADING.setLoading(false, "");

        }).catch(ex => {
            console.log(ex)
            LOADING.setLoading(false, "");
            alert("There was an error loading your payment profile")
            navigate("/store/payments");
        });
    }

    function goBack(){
        navigate("/store/payments", false);
    }

    async function onSubmit(e) {
        const formData = new FormData(e.target);      
        
        if(e.submitter && setBusy){
            setBusy(e.submitter);
        }    

        var passed_validation = true;

        if(token_chain == "btc_mainnet"){
            var WALLET_PATTERN = /^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$/;

        }else if(token_chain == "eth_mainnet" || token_chain == "eth_testnet"){
            var WALLET_PATTERN = /^0x[a-fA-F0-9]{40}$/;
            passed_validation = WALLET_PATTERN.test(dest);
            if(!passed_validation){
                console.log("Invalid EVM Wallet");
                pushNotify("error", "Invalid Wallet", "Please use a valid EVM wallet address")                
            }
        }else if(token_chain == "icp_mainnet" || token_chain == "icp_testnet"){
            var WALLET_PATTERN = /^(([a-zA-Z0-9]{5}-){4}|([a-zA-Z0-9]{5}-){10})[a-zA-Z0-9]{3}(-[a-zA-Z0-9]{7}\.[a-fA-F0-9]{1,64})?$/;
            passed_validation = WALLET_PATTERN.test(dest);
            if(!passed_validation){
                console.log("Invalid ICP Wallet");
                pushNotify("error", "Invalid Wallet", "Please use a valid ICP wallet address")
            }            
        }else if(token_chain == "sol_mainnet"){
            var WALLET_PATTERN = /^([A-Za-z0-9]{44})$/;
            passed_validation = WALLET_PATTERN.test(dest);
            if(!passed_validation){
                console.log("Invalid SOL Wallet");
                pushNotify("error", "Invalid Wallet", "Please use a valid SOL wallet address")
            }
        }

        if(!passed_validation){
            removeBusy();
            //navigate("/store/payments");
            return;
        }

        await updatePaymentSetting().catch(err => {
            console.log(err);                       
            throw err;
        });

        console.log("finished updating");
    }

    async function updatePaymentSetting(setting){
        console.log("updating settting..... ")
        //console.log(setting)
        const updated_setting = await $auth.actor.updatePaymentSetting(slug, token_chain, dest, is_enabled);
        console.log("UPDATE RESULT: " + updated_setting);
        if(updated_setting){
            //alert("Saved payment setting");
            pushNotify("success", "Saved", "Payment setting saved");
        }else{
            alert("Error - There was an error updating this setting\nPlease check the logs");
        }
        removeBusy();
        navigate("/store/payments");
    }

    function setBusy(sender){    
      if(!sender) {
        console.log("tried to set a null element to busy");
        return;
      }
      sender.setAttribute('aria-busy', 'true');      
      document.getElementById("cancel_edit").style.display = "none";
      return;
    }

    function toggleType(event){
        if(event.target.checked){
            document.getElementById("dest").type = "text";
            return;
        }
        document.getElementById("dest").type = "password";        
        return;
    }

</script>

{#if (is_insert)}
    <h1>Add Payment Setting</h1>
{:else}
    <h1>Edit Payment Setting</h1>
{/if}
<article>
    <img src={token_image_url} alt="" class="token-icon" />&nbsp;&nbsp;<b>{token_name} - {token_description}</b>
</article>
<section>
    <form on:submit|preventDefault={onSubmit}>       
        
          <article class="nopadding">   
           
            <fieldset>
               
                <input type="hidden" value={slug} name="slug" />
                <input type="hidden" value={guid} name="guid" />

                <input type="hidden" value={updated_at} name="updated_at" />
                <input type="hidden" value={created_at} name="created_at" />                
                <input type="hidden" value={token_chain} name="chain" />
                
              
                <label for="is_enabled">
                <input type="radio" id="is_enabled" name="is_enabled" value={true} bind:group={is_enabled} >
                {#if (is_enabled) }
                    <span class="pico-color-green-250">Enabled</span>
                {:else}
                    <span >Enabled</span>
                {/if}      
                </label>            
                <label for="is_enabled2">
                <input type="radio" id="is_enabled2" name="is_enabled"  value={false} bind:group={is_enabled} >          
                {#if (!is_enabled) }
                    <span class="pico-color-orange-500">Disabled</span>
                {:else}
                <span>Disabled</span>
                {/if}       
                </label>            
            </fieldset>          
            <fieldset>
                <p>Chain: <code class="pico-color-green-250">{token_chain}</code></p>
            </fieldset>
            <fieldset>
                <label for="dest">      
                    Destination Address              
                    <input type="password" id="dest" name="dest" bind:value={dest} placeholder="destination address ..." required autocomplete="off" maxlength=128 class="update-field" />
                </label>                
                <p>
                    <label for="show_password">                       
                        <input type="checkbox" value="show" id="show_password" name="show_password" on:change={(e) => toggleType(e)} />
                        Preview Address
                    </label>
                </p>
                <span class="pico-color-orange-250">WARNING - Please ensure the address is correct for <b><em data-tooltip="{token_chain_tooltip}">{token_chain}</em></b></span>                
              </fieldset>
            <fieldset>
          
          </article>
       
          <fieldset>            
            {#if (is_insert)}
              <span></span>
            {:else}
            <p>updated: {@html timeAgoFromEpoch(updated_at) == "Just now" ? "<span style='color: lawngreen;'>Just now</span>" : timeAgoFromEpoch(updated_at)}</p>
            <p>created: {timeAgoFromEpoch(created_at) == "Invalid date" ? "" : timeAgoFromEpoch(created_at)}</p>
            {/if}
            
          
          </fieldset>          

        
        <button type="submit" on:click{onSubmit}>Save</button>
        <br>        
        <button id="cancel_edit" class="secondary" on:click|preventDefault={goBack}>Back</button>
        
      </form>  

</section>

<style>
    .token-icon{
        width: 32px;
        height: 32px;
        vertical-align:auto;
    }
  </style>