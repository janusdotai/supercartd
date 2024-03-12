<script>
import { onMount, afterUpdate } from "svelte";
import { auth, user, token, IS_PRODUCTION } from "../store/auth";
import { getTimestampEpoch, timeAgoFromEpoch, pushNotify } from "../store/utils.js"
import { Router, Link, Route, navigate } from "svelte-routing";

$: is_loggedIn = $auth.loggedIn;
$: testname = $user.name;
$: principal = $user.principal;
$: login_since = $user.updated_at || 1;
$: current_token = $token;

let ms = $user.updated_at * 1000;
let dt = new Date(ms);

afterUpdate(async () => {
	if(is_loggedIn){
		pushNotify("success", "Welcome", "You are logged in");		
	}
});
  
</script>

	{#if is_loggedIn === true }
		<div style="height: 50px;"></div>
		<article>
			<h1 class="pico-color-green-250">Authenticated</h1>
			<div id="logged_in_view" style="display: block;">
				<!-- <h1>YOU ARE LOGGED IN </h1>			 -->
				<h5>Principal: <code>{principal}</code></h5>
				<h5>Name: <code>{testname}</code></h5>
				<h5>Since: <code>{dt} - {@html timeAgoFromEpoch(login_since) == "Just now" ? "<span style='color: lawngreen;'>Just now</span>" : timeAgoFromEpoch(login_since)}</code></h5>
				<h5>Token: <code>{current_token} (Testnet)</code></h5>
			</div>
		</article>
		<br>
		<article>
			<details>
				<summary>Quick Start Guide</summary>
				<p>Beofre you can begin to sell online you must complete 3 steps to enable the storefront</p>
				<ol>
				  <li><a href="/store/edit" title="create checkout">Create a checkout</a> - create/edit and save</li>
				  <li><a href="/store/products">Add a product</a> - add a new product and save</li>
				  <li><a href="/store/payments">Configure payment</a> - edit payments and add your wallet</li>
				</ol>
				<p>If you complete all 3 above steps and your checkout is 'enabed'
					you should see a View Checkout link. This is your public checkout URL which can also be found
					at the bottom of the admin page.					
				</p>
				
			  </details>
		</article>
		
		<section class="action-area">
			<Link to="/admin"  role="button" >Store Config</Link>
		</section>	

	{:else}

		<h1>Supercartd</h1>
		<div class="hero space">
			<div class="title">
				<h1 class="serif capitalize"><span>TECHNICAL DEMO</span></h1>
				<h4>login to start</h4>
			</div>
			<div class="quote">
				<article>
					<p class="serif">A multichain ecommerce system</p>
					<footer>
					<a href="/admin">Explore the App →</a>
					</footer>
				</article>
			</div>
		</div>
		  		
	{/if}

 

<style>
	.hero {
		position: relative;
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		grid-template-rows: repeat(4, 140px);

		/* creates new stacking context for z-index */
		isolation: isolate;
	}

	.hero::after {
		content: '';
		grid-row: 1 / -1;
		grid-column: 3 / -1;
		background-image: url('/images/covera.png');
		background-size: cover;
		border: 10px solid;
		border-image-slice: 1;
		border-image-source: linear-gradient(
			to left,
			orange,
			orangered
		);
		z-index: -10;
	}

	.title {
		height: 100%;
		grid-column: 1 / 4;
		grid-row: 1 / 3;
		display: grid;
		place-content: center;
	}

	.quote {
		grid-column: 1 / 4;
		grid-row: 3;
		padding: 1rem;
	}

	article {
		margin: 0;
	}

	.action-area{
		border: none 1px blue;
		margin-top: 100px;
		text-align: center;
	}
</style>
