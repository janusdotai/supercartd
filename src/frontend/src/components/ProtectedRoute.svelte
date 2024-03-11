<script>
    import { onMount } from "svelte";
    import { Route, Link } from 'svelte-routing';
    import accessDenied from '../routes/AccessDenied.svelte';
    import { token, auth } from '../store/auth.js';

    export let path;
    export let component;    
    //export let params;

    $: isAuthenticated = $auth.loggedIn;     


    
</script>

{#if isAuthenticated}
    <Route path={path} component={component} />
{:else}
    <Route path={path} component={accessDenied} />
{/if}