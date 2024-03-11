<!-- <script>
    import { onMount, afterUpdate } from "svelte";
    import { auth, user, token } from "../store/auth.js";
    import { Link } from "svelte-routing";
    import { LOADING, removeBusy } from "../store/loader.js";
    import { timeAgoFromSecondEpoch, timeAgoFromEpoch, toDateFromSeconds, timeAgo, flatten, first, pushNotify } from "../store/utils.js"
    
    let tokens = [];
    let chains = [];    
    
    onMount(async () => {   
        //LOADING.setLoading(true, "Loading tokens ....")
        await bind_store_tokens();
        //LOADING.setLoading(false, "")
    });
    
    async function bind_tokens(){
        //console.log("im binding tokens")
        
        const ignore = await $auth.actor.getTokens().then(x => {
            //console.log(x);        
            var unsorted = x;      
            unsorted.sort(function(a, b){
              return a.name.localeCompare(b.name);
            });
            tokens = unsorted;
            token_result_busy = false;
        });

        const ignore2 = await $auth.actor.getChains().then(x => {
            //console.log(x);        
            var unsorted = x;      
            unsorted.sort(function(a, b){
              return a.name.localeCompare(b.name);
            });
            chains = unsorted;
            chain_result_busy = false;
        });
    };

</script>
`
<h1>list of tokens</h1>`` -->