
<script>
    import { onMount, afterUpdate } from "svelte";
    import { auth, user, token } from "../store/auth.js";
    import { Link, navigate } from "svelte-routing";
    import { getTimestampEpoch, timeAgoFromEpoch, ellipsis, stripHtmlTags, pushNotify, key2val } from "../store/utils.js"
    import { LOADING, removeBusy } from "../store/loader.js";

    export let id = "0"; //product id

    $: cid = ""; //checkout id   

    let sku; //product sku
    let foreign_key;
    let is_enabled = false;

    let name;
    let description;
    let description2
    let price;
    
    let tax1rate = 0.00;
    let tax2rate = 0.00;
    let tax_mode = "inclusive";
    let tax_mode_tooltip = "Price includes taxes"

    let created_at;
    let updated_at;

    let image_url;
    let tags = [];

    let is_insert = (id == "0" || id == undefined) ? true : false;

    
    onMount(async () => {        
        //console.log("productId : " + id);      
        bind_merchant().then(x => {
          //console.log("loaded checkout id " + cid);
        });
    });

    async function bind_merchant(){
        const merchant_response = await $auth.actor.getMerchant().then(m => {            
            let data = m["data"][0] || [];
            if(data.length == 0)           {
              console.log("error loading merchant..")             
              pushNotify("error", "Error", "Merchant could not be loaded, please try again")              
              LOADING.setLoading(false, "");
            //  alert("error loading merchant")
              navigate("/store/products", false)
              return false;
            }            
            //console.log(m)
            //console.log(data)
            cid = data["cid"]
            //console.log("checkout id " + cid);            
            tryGetProduct(id);
        });

    }
 

    async function tryGetProduct(id){
        if(id == undefined || id == null || id == "0"){
            //console.log("New Product")
            created_at = getTimestampEpoch();
            updated_at = getTimestampEpoch();

            return;
        };
        LOADING.setLoading(true, "Loading product ... ");
        const product = $auth.actor.getMerchantProduct(id).then(x => {
            let response = x[0]["data"];
            if(response.length == 0)           {
              console.log("error loading product..")
              alert("error loading product.")
              pushNotify("error", "Product", "Error loading product!")
              navigate("/store/products", false)
            }
            //console.log(response);
            let product = response[0];            
            //console.log(product);
            name = product["name"] ?? "";
            sku = product["sku"] ?? "";
            description = product["description"] ?? "";
            description2 = product["description2"] ?? "";     

            price = product["price"] ?? "";     
            image_url = product["image_url"] ?? "";     
            tax1rate = product["tax1rate"] ?? "";     
            tax2rate = product["tax2rate"] ?? "";

            is_enabled =  product["is_enabled"] === true ? true : false;
            updated_at = product["updated_at"]
            created_at = product["created_at"]
            //console.log(product["is_enabled"])
            
            if(product["tax_mode"] && product["tax_mode"] != "0"){
              tax_mode =  key2val(product["tax_mode"]);
            }            
            //console.log(tax_mode)

           // console.log("taxtest:" + tax_mode)
            if(tax_mode == "inclusive"){
              document.getElementById("tax_mode").checked = true;
              tax_mode_tooltip = "Price includes taxes";
              document.getElementById("tax_mode_details").style.display = "none";
            }else{
              document.getElementById("tax_mode").checked = false;
              tax_mode_tooltip = "Price excludes taxes";
              document.getElementById("tax_mode_details").style.display = "block";
            }

            LOADING.setLoading(false, "");                   

        });
    };

    async function onSubmit(e) {
      const formData = new FormData(e.target);      
      //set button to busy ... 
    //   if(e.submitter && setBusy){
    //     setBusy(e.submitter);
    //   }
      
      //CONVERT TYPES TO ICP
      const data = {};
      for (let field of formData) {        
        //console.log(field)
        const [key, value] = field;
        data[key] = value;       

        if(field[0] == "is_enabled"){ //optional field          
          var isTrueSet = (data[key] === 'true');
          //console.log("handled is_enabled isTrueSet " + isTrueSet)
          data[key] = isTrueSet;
          //console.log("handled is_enabled opt?")
        }

        if(field[0] == "price"){
          //console.log("price ")
          data[key] = parseFloat(data[key]);
        }
        
        if(field[0] == "created_at"){
          if(is_insert){
            data[key] = getTimestampEpoch();
          }else{
            data[key] = created_at;
          }        
        }

        if(field[0] == "updated_at"){
          //console.log("getTimestampEpoch ")
          data[key] = getTimestampEpoch();
        }

        if(field[0] == "tax1rate"){          
          data[key] = parseFloat(data[key]);
          //console.log("handled tax1rate conversion")
        }

        if(field[0] == "tax2rate"){          
          data[key] = parseFloat(data[key]);
          //console.log("handled tax2rate conversion")
        }

        if(field[0] == "image_url"){ //optional field
          let url = stripHtmlTags(data[key]);
          data[key] = [url];          
          //console.log("handled image_url opt?")
        }

        if(field[0] == "name"){          
          data[key] = stripHtmlTags(data[key]);
        }
        if(field[0] == "sku"){          
          data[key] = stripHtmlTags(data[key]);
        }
        if(field[0] == "description"){          
          data[key] = stripHtmlTags(data[key]);
        }

     
      }

      if(document.getElementById("tax_mode").checked){
        data["tax_mode"] = { 'inclusive' : null };
        data["tax1rate"] = 0.00
        data["tax2rate"] = 0.00
        
      }else{
        data["tax_mode"] = { 'exclusive' : null };
        var rate1 = parseFloat(data["tax1rate"]);
        if(rate1 >= 1 || rate1 == 0){
         // alert("Tax 1 rate must be a decimal number like 0.07 for 7%");
          pushNotify("error", "Tax 1 rate", "Tax 1 rate must be a decimal number like 0.07");
          return;
        }
        var rate2 = parseFloat(data["tax2rate"]);
        if(rate2 >= 1){
         // alert("Tax 1 rate must be a decimal number like 0.07 for 7%");
          pushNotify("error", "Tax 2 rate", "Tax 2 rate must be 0 or a decimal");
          return;
        }

        // if(parseFloat(data["tax2rate"]) > 0){
        //   alert("Tax 2 rate cannot be 0.00");
        //   return;
        // }

      }

      data["description2"] = [""];
      data["tags"] = [[""]];
      data["foreign_key"] = [""];

     // console.log(data)

      await updateProduct(data).catch(err => {
        console.log(err);        
        console.log(data);
        throw err;
      });

      //removeBusy();
      //document.getElementById("cancel_edit").style.display = "block";            
    }


    const updateProduct = async (product) => {
      LOADING.setLoading(true, "");      
      if(!cid || cid.length < 50){
        console.log("problem with this form .. exiting")
        alert("Fatal error no cid!");
        LOADING.setLoading(false, "");
        return;
      }

      const response = await $auth.actor.updateMerchantProduct(cid, product);
      //console.log(response);
      if (response.status === 200) {
          if (!response.data){
              console.log("bad response status ..exiting");
              return;
          }        

          LOADING.setLoading(false, "");
          console.log("merchant updated");

          navigate("/store/products", true);

      }else{ //error updating
        LOADING.setLoading(false, "");
        //console.log(response)
        let error_text = "";
        if(response.error_text && response.error_text.length > 0){
          error_text = response.error_text[0]
        }
        alert("There was an error updating the product\n\n" + error_text);
      }       

    };

    function display_tax_info(){
      return "this is how taxes are calculated for this sku";
    }

    function updateTaxClass(e){
      //console.log("updateTaxClass")
      //console.log(e.target.checked)
      if(e.target.checked){
        tax_mode = "inclusive";
        tax_mode_tooltip = "Price includes taxes";
        document.getElementById("tax_mode_details").style.display = "none";

      }else{
        tax_mode = "exclusive";
        tax_mode_tooltip = "Price does not include taxes";
        document.getElementById("tax_mode_details").style.display = "block";

      }

    }

    function goBack(){
        navigate("/store/products", false);
    }

</script>



{#if (!is_insert)}
  <h1>EDIT Product</h1>
  <div style="float: right; border: none 1px blue;">SKU:<code class="large"><b>{sku}</b></code></div>
{:else}
  <h1>ADD Product</h1>
{/if}
<section>
    <form on:submit|preventDefault={onSubmit}>
       
          <!-- <section class="pico-color-red-500" id="checkout_warning">
            No checkout found, create a new one below:
          </section>  
          <section class="pico-color-green-500" id="checkout_success">
            Checkout was updated successfully.
          </section>      
           -->
          <article class="nopadding">   
           
            <fieldset>
                <input type="hidden" value={id} name="pid" />
                <input type="hidden" value={updated_at} name="updated_at" />
                <input type="hidden" value={created_at} name="created_at" />          
                <input type="hidden" value={cid} name="cid" />
            
                <label for="is_enabled">
                <input type="radio" id="is_enabled" name="is_enabled" value={true} bind:group={is_enabled} >
                {#if (is_enabled) }
                    <span class="pico-color-green-500">Enabled</span>
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
            <label for="name">
                Name
                <input type="text" id="name" name="name" bind:value={name} placeholder="product name ..." required autocomplete="off" maxlength=50 class="update-field"/>
            </label>
        
            <label for="sku">
                SKU
                <input type="text" id="sku" name="sku" bind:value={sku} placeholder="XYZ-123" required autocomplete="off" maxlength=50 class="update-field"/>        
            </label>

            <label for="description">
                Description
                <input type="text" id="description" name="description" bind:value={description} placeholder="" required autocomplete="off" maxlength=50 class="update-field"/>        
            </label>

            <!-- <label for="description2">
                <p class="update-field">Description 2</p>                
                <input type="text" id="description2" name="description2" bind:value={description2} placeholder="" required autocomplete="off" maxlength=50 class="update-field"/>        
            </label> -->

            <label for="price">
                Price
                <input type="text" id="price" name="price" bind:value={price} placeholder="1.99" required autocomplete="off" maxlength=50 class="update-field"/>
            </label>
            <section>
              Tax 
              <label >
                <div style="height: 5px;"></div>
                <input type="checkbox" name="tax_mode" id="tax_mode" checked on:change={(event) => updateTaxClass(event)} 
                />
                <span id="tax_mode_label" data-tooltip="{tax_mode_tooltip}">{tax_mode}</span>
              </label>
              <div><code id="tax_mode_tooltip"><b>{tax_mode_tooltip}</b></code></div>
              <section id="tax_mode_details" class="tax-mode-details">
                <label for="price">
                  Tax 1
                  <input type="text" id="tax1rate" name="tax1rate" bind:value={tax1rate} placeholder="0.07" required autocomplete="off" maxlength=6 class="update-field"/>
              </label>
              <label for="tax2rate">
                Tax 2
                <input type="text" id="tax2rate" name="tax2rate" bind:value={tax2rate} placeholder="0.05" required autocomplete="off" maxlength=6 class="update-field"/>
              </label>
              </section>
            </section>
            
           
            <label for="image_url">
              <p class="update-field">Image</p>
              <input type="text" id="image_url" name="image_url" bind:value={image_url} placeholder="url ..." autocomplete="off" maxlength=200 class="update-field"/>
            </label>      
            <div>
              {#if (image_url)}
                <img src={image_url} alt="" style="width: 50%; height: 50%;" />
              {/if}
            </div>
          
          </article>
          <!-- <fieldset>
            <code>{id}</code>
          </fieldset> -->

          <fieldset>
           
            <input type="hidden" value={tax1rate} name="tax1rate"  />
            <input type="hidden" value={tax2rate} name="tax2rate" />

          </fieldset>

          <fieldset>            
            {#if (is_insert)}
              <span></span>
            {:else}
            <p>updated: {@html timeAgoFromEpoch(updated_at) == "Just now" ? "<span style='color: lawngreen;'>Just now</span>" : timeAgoFromEpoch(updated_at)}</p>
            {/if}
            <p>created: {timeAgoFromEpoch(created_at)}</p>

          </fieldset>
        
        <button type="submit" on:click{onSubmit}>Save</button>
        <br>        
        <button class="secondary" on:click|preventDefault={goBack}>Back</button>
        
      </form>  

</section>
<style>
  .tax-mode-details{
    display: none;
  }
  .large{
    font-size: larger;
    color: lawngreen;
  }
</style>

