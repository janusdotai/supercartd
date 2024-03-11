<script>
  import { AuthClient } from "@dfinity/auth-client";
  import { onMount } from "svelte";
  import { auth, createActor, IS_PRODUCTION, token, user } from "../store/auth";
  import { Principal } from "@dfinity/principal";

  /** @type {AuthClient} */
  let client;
  
  let whoami = $auth.actor.whoami();

  $: principal_id = "";

  let login_class = $auth.loggedIn === true ? "login-on" : "login-off";

  onMount(async () => {
    client = await AuthClient.create();    
    if (await client.isAuthenticated()) {      
      var p = client.getIdentity().getPrincipal();      
      principal_id = p.toString();
      handleSuccessAuth();
      login_class = $auth.loggedIn === true ? "login-on" : "login-off";      
    }
  });    

  function handleSuccessAuth() {
    auth.update(() => ({
      loggedIn: true,
      actor: createActor({
        agentOptions: {
          identity: client.getIdentity(),
        },
      }),
    }));
    
    user.update(() => ({
      updated_at: Math.round(new Date().getTime() / 1000, 2),
      name: "testnet alpha user",
      principal : principal_id,
      account : "",
      chain_id: 0
    }));
    
    whoami = $auth.actor.whoami();

    localStorage.setItem('scdtoken', '1');
    token.set(localStorage.getItem('scdtoken'));
  }

  function handleErrorAuth() {
    auth.update(() => ({
      loggedIn: false,
      actor: createActor() }));
    console.log("------------FATAL LOGIN ERROR ------------------------------------------");
    localStorage.clear();
    token.set(null);
    //throw Error;
  }

  function login() {
    client.login({
      identityProvider:
        process.env.DFX_NETWORK === "ic"
          ? "https://identity.ic0.app/#authorize"
          : `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:8080/#authorize`,          
      onSuccess: handleSuccessAuth, 
      onError: handleErrorAuth
    });
  }

  async function logout() {
    await client.logout();
    auth.update(() => ({
      loggedIn: false,
      actor: createActor(),
    }));    
    whoami = Principal.anonymous();
    localStorage.clear();
    token.set(null);
  }

  function truncatePrincipal(p){    
    if(!p){
      return "anon";
    }      
    var addr = p.toString();
    var x = addr.substring(0, 5)
    var y = addr.slice(-3)
    return x + "..." + y;
  }

  
</script>

<div class="login-links">
  {#if $auth.loggedIn}
    <div>      
      <a href={'javascript:void(0)'} on:click={logout} class="contrast">Log out</a>      
    </div>
  {:else}
  <div>    
    <a href={'javascript:void(0)'} on:click={login} class="contrast">Login</a>
  </div>
  {/if}

  <div class="principal-info">
    {#await whoami}
      fetching identity ...
    {:then principal}      

      {#if $auth.loggedIn}
        <br /><code data-tooltip="My profile" data-theme="dark" ><a href="/admin"><span class="login-on" ><small>{truncatePrincipal(principal)}</small></span></a></code>        
      {:else}
        <br />
        <code data-tooltip={principal} data-theme="dark" ><span class="login-off"><small>{truncatePrincipal(principal)}</small></span></code>
      {/if}
      
      {#if principal.isAnonymous()}
        <span>(anon)</span>
      {/if}
    {:catch error}
       <!-- <span>{error}</span> -->       
    {/await}
  </div>
</div>

<style> 
  .principal-info {
    margin-top: 1px;
    font-size: smaller;
  }
  .login-links{
    text-align: right;
  }

  .login-on{
    color: lawngreen;
  }

  .login-off{
    color: orange;
  }

</style>
