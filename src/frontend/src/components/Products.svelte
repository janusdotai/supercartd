
<script>
    import { Link, navigate } from "svelte-routing";
    import { onMount, afterUpdate } from "svelte";
    import { auth, user, token } from "../store/auth.js";
    import { timeAgoFromSecondEpoch, ellipsis, pushNotify } from "../store/utils.js";
    import { LOADING, removeBusy } from "../store/loader.js";
    
    let product_catalog = [];
    
    onMount(async () => {
      //let principal = await $auth.actor.whoami();
      //console.log("principal : " + principal.toString());      
      await bind_merchant();
    });

    async function bind_merchant(){
        //console.log("loading products")
        LOADING.setLoading(true, "");      
        let merchant_response = await $auth.actor.getMerchant().then(m => {
            let data = m["data"][0]            
            //console.log(m)
            //console.log(data)
            let cid = data["cid"]
            //console.log(cid)
            bind_products(cid)        
        });        
    }

    async function bind_products(cid){
        //console.log("binding product catalog for id " + cid)
        let stuff = await $auth.actor.getMerchantProducts(cid).then(p => {
            //console.log(p)
            let data = p["data"] || [];            
            product_catalog = data[0];
            //console.log(product_catalog)
            LOADING.setLoading(false, "");
        }).catch(e => {
            console.log(e);
            LOADING.setLoading(false, "");
            pushNotify("Error", "Failed to load products", "error");
        })

    }
    
    function goBack(){
        navigate("/admin", false);
    }

    function addProduct(){
        navigate("/store/products/add", false);
    }

    function editProduct(pid){
        let url ="/store/products/edit/" + pid;
        navigate(url, false);
    }

    function formatEnabled(enabled){
        if(enabled){
            return "<span class='pico-color-green-500'>Enabled</span>";
        }
        return "<span class='pico-color-orange-500'>Disabled</span>";
    }

    
</script>

<nav aria-label="breadcrumb">
    <ul>
      <li><Link to="/" title="Home">Home</Link></li>
      <li>
        <Link to="/admin" title="Admin">Admin</Link>
      </li>
      <li>Products</li>
    </ul>
</nav>
<section>
    <h1>Product Catalog</h1>
</section>
<section>   

    {#if (product_catalog.length == 0)}        
        <section class="pico-color-red-500" id="checkout_warning">
            No products found, create a NEW one:
        </section>        
    {:else}      
        <div>
            <table>
                <thead>
                  <tr>
                    <th scope="col">Id</th>
                    <th scope="col">Name</th>
                    <th scope="col">Sku</th>      
                    <th scope="col">Price</th>
                    <th scope="col">Updated</th>
                    <th scope="col">Status</th>
                    <th scope="col"></th>
                  </tr>
                </thead>
            
                <tbody>
                {#if product_catalog.length > 0}
                    {#each product_catalog as entry, index(entry[0])}
                    {@const pid = entry[1]["pid"]}
                    {@const name = entry[1]["name"]}
                    {@const sku = entry[1]["sku"]}
                    {@const price = entry[1]["price"]}
                    {@const updated_at = entry[1]["updated_at"]}
                    {@const is_enabled = entry[1]["is_enabled"]}
                    {@const tax_mode = entry[1]["tax_mode"]}
                    <tr>                      
                      <!-- svelte-ignore a11y-invalid-attribute -->
                      <td><a href="#" on:click={editProduct(pid)}>{ellipsis(pid, 6)}</a></td>
                      <td>{name}</td>
                      <td>{sku}</td>
                      <td>{price}</td>
                    
                      <td>{timeAgoFromSecondEpoch(updated_at)}</td>        
                      <td>{@html formatEnabled(is_enabled)}</td>
                      <!-- svelte-ignore a11y-invalid-attribute -->
                      <td><a href="#" on:click={editProduct(pid)}>edit</a></td>
                    </tr>        
                    {/each}
                  {/if}
                </tbody>
              
              </table>
        </div>
    {/if}    
</section>

<hr>
<br>
<p>
    <button on:click={addProduct}>New Product</button>
</p>
<p>
    <button class="secondary" on:click={goBack}>Back</button>
</p>