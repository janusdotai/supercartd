<script>
  import { Link, navigate } from "svelte-routing";
  import { onMount, afterUpdate } from "svelte";
  import { auth, user, token } from "../store/auth.js";
  import { LOADING, removeBusy } from "../store/loader.js";
  import { getTimestampEpoch, timeAgoFromEpoch, stripHtmlTags, pushNotify } from "../store/utils.js"

  let MODEL_LOADED = false;
  
  let cid = getTimestampEpoch().toString();
  let name = null;
  let email_address = null;
  let email_notifications = false;
  let phone_number = null;
  let phone_notifications = false;
  let created_at = null;
  let updated_at = null;    

  let is_enabled = false;
  let is_maintenance_mode = false;    

  onMount(async () => {    
    await bind_merchant();
  });

  async function bind_merchant(){

    let merchant = await get_merchant();
    if(merchant){        
      
      cid = merchant["cid"] ?? getTimestampEpoch().toString();
      name = stripHtmlTags(merchant["name"] ?? "");
      email_address = stripHtmlTags(merchant["email_address"] ?? "");
      email_notifications = merchant["email_notifications"];
      phone_number = stripHtmlTags(merchant["phone_number"] ?? "");
      phone_notifications = merchant["phone_notifications"];
      is_enabled = merchant["is_enabled"];
      //is_maintenance_mode = merchant["is_maintenance_mode"];
      
      const unixTimestampInSeconds = Math.floor(Date.now() / 1000);
      created_at = merchant["created_at"] == 0 ? unixTimestampInSeconds : merchant["created_at"];
      updated_at = merchant["updated_at"] == 0 ? unixTimestampInSeconds : merchant["updated_at"];

      MODEL_LOADED = true;

    }else{
      
      MODEL_LOADED = false;
      document.querySelectorAll(".update-field").forEach(x => {
        //console.log(x);
        //x.setAttribute("area-busy", "true");
      });

    }

  }

  async function get_merchant(){      
    LOADING.setLoading(true, "");
    let merchant_response = await $auth.actor.getMerchant();
    //console.log(merchant_response);
    LOADING.setLoading(false, "");

    let status = merchant_response["status"];
    let status_text = merchant_response["status_text"];
    let error_text = merchant_response["error_text"];
    let merchant = merchant_response["data"][0];

    if(status != 200){
      console.log("no merchant found: status " + status)
      pushNotify("error", "Error", "no merchant found")

      document.getElementById("checkout_warning").innerHTML = "No checkout found, create new:";
      document.getElementById("checkout_warning").style.display = 'block';
      return null;
    }
    
    return merchant;

  }

  const updateMerchant = async (merchant) => {      
    LOADING.setLoading(true, "");

    const response = await $auth.actor.updateMerchant(merchant);
    //console.log(response);     

    if (response.status === 200) {
      if (!response.data) return;

      let updated_merchant = response.data[0];
      name = stripHtmlTags(updated_merchant["name"] ?? "");
      email_address = stripHtmlTags(updated_merchant["email_address"] ?? "");
      email_notifications = updated_merchant["email_notifications"];

      phone_number = stripHtmlTags(updated_merchant["phone_number"] ?? "");
      phone_notifications = updated_merchant["phone_notifications"];

      created_at = updated_merchant["created_at"];
      updated_at = updated_merchant["updated_at"];

      is_enabled = merchant["is_enabled"];
      is_maintenance_mode = merchant["is_maintenance_mode"];
      //console.log(updated_merchant)

      let status = response["status"]
      let status_text = response["status_text"]

      let msg = "Checkout update success: "
      document.querySelectorAll(".checkout_success").forEach(x => {
        x.style.display = 'block';
        x.innerHTML = msg + status + ' ' + status_text;
      });
      //document.getElementById("checkout_success").style.display = "block";
      //let msg = "Checkout update success: "
      //document.getElementById("checkout_success").innerHTML = msg + status + ' ' + status_text;

      document.getElementById("checkout_warning").style.display = 'none';

    }
    LOADING.setLoading(false, "");
    
    console.log("merchant updated");
    return response;

  };


  async function onSubmit(e) {
    const formData = new FormData(e.target);
    //console.log(e);      
    //set button to busy ... 
    if(e.submitter){
      setBusy(e.submitter);
    }    
    //CONVERT TYPES TO ICP
    const data = {};
    for (let field of formData) {        
      //console.log(field)
      const [key, value] = field;
      data[key] = value;

      if(field[0] == "created_at"){        
        data[key] = data[key] ? Number(data[key]) : getTimestampEpoch();
      }

      if(field[0] == "updated_at"){        
        data[key] = getTimestampEpoch();
      }

      if(field[0] == "phone_notifications"){          
        data[key] = field[1] == "true" ? true : false;          
      }else if(field[0] == "email_notifications"){         
        data[key] = field[1] == "true" ? true : false;          
      }

      if(field[0] == "is_enabled"){          
        data[key] = field[1] == "true" ? true : false;          
      }else if(field[0] == "is_maintenance_mode"){
        data[key] = field[1] == "true" ? true : false;          
      }
    }

    //console.log(data)
    await updateMerchant(data).catch(err => {
      console.log(err);
      MODEL_LOADED = False;
      //console.log(data);
      throw err;
    });

    removeBusy();
    document.getElementById("cancel_edit").style.display = "block";
    //window.scroll(0,0);
    //window.scrollTo({ top: 0, left: 0, behavior: 'smooth' });
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


</script>
<header>
<nav aria-label="breadcrumb">
    <ul>
      <li><Link to="/" title="Home">Home</Link></li>
      <li>
        <Link to="/admin" title="Admin">Admin</Link>
      </li>
      <li>Edit Store</li>
    </ul>
</nav>
</header>

<h2>Checkout Configuration</h2>
<form on:submit|preventDefault={onSubmit}>
  <div class="grid">  
    <div>    
    <section class="pico-color-red-500 checkout_warning" id="checkout_warning">
      No checkout found, create a new one below:
    </section>  
    <section class="pico-color-green-500 checkout_success" id="checkout_success">
      Checkout was updated successfully.
    </section>      
    <!-- <h4 class="pico-color-pink-500" style="display: {MODEL_LOADED ? "none" : "block"}">Loading checkout...</h4> -->
    <article class="nopadding">   
      <fieldset>
        Checkout ID <code>{cid}</code>
      </fieldset>     
      <fieldset >
        <legend>Status</legend>
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
      
      <label for="name">
        <p class="update-field">Checkout Name</p>
        <input type="text" id="name" name="name" bind:value={name} placeholder="checkout name ..." required autocomplete="off" maxlength=30 class="update-field"/>
      </label>
      <label for="email_address">
        Email
        <input type="text" id="email_address" name="email_address" bind:value={email_address} placeholder="checkout email ..." required autocomplete="off" maxlength=200 class="update-field"/>
      </label>
      <label for="phone_number">
        Phone
        <input type="text" id="phone_number" name="phone_number" bind:value={phone_number} placeholder="checkout phone ..." required autocomplete="off" maxlength=20 class="update-field"/>
      </label>
    </article>

    <fieldset>
      <legend>Email Notifications</legend>
      <label for="email_notifications1">
        <input type="radio" id="email_notifications1" name="email_notifications" value={true} bind:group={email_notifications}>
        Enabled
      </label>
      <label for="email_notifications2">
        <input type="radio" id="email_notifications2" name="email_notifications"  value={false} bind:group={email_notifications}>
        Disabled
      </label>      
    </fieldset>

    <fieldset>
      <legend>SMS Notifications</legend>
      <label for="phone_notifications1">
        <input type="radio" id="phone_notifications1" name="phone_notifications" value={true} bind:group={phone_notifications}>
        Enabled
      </label>
      <label for="phone_notifications2">
        <input type="radio" id="phone_notifications2" name="phone_notifications"  value={false} bind:group={phone_notifications}>
        Disabled
      </label>      
    </fieldset>
      
    <fieldset>      
      <p>updated: {@html timeAgoFromEpoch(updated_at) == "Just now" ? "<span style='color: lawngreen;'>Just now</span>" : timeAgoFromEpoch(updated_at)}</p>
      <input type="hidden" value={updated_at} name="updated_at" />      
      <p>created: {timeAgoFromEpoch(created_at)}</p>

      <input type="hidden" value={created_at} name="created_at" />
      <input type="hidden" value={cid} name="cid" />
    </fieldset>

    <section class="pico-color-green-500 checkout_success" id="checkout_success">
      Checkout was updated successfully.
    </section>      
    <section class="pico-color-red-500 checkout_warning" id="checkout_warning">
      No checkout found, create a new one below:
    </section>  


  </div>
  </div>
  <button type="submit" on:click{setBusy}>Submit</button>
  <br>
  <a href="/" role="button" class="secondary" id="cancel_edit" style="display: block;">Back</a>
</form>  

<style>

  .nopadding{
    margin-top: -20px;    
    border: none 1px blue;
  }

  #checkout_warning, #checkout_success{
    display: none;
  }

</style>