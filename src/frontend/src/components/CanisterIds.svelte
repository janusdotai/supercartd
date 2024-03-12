<script>
  import { IS_PRODUCTION } from "../store/auth";

</script>
{#if (IS_PRODUCTION)}
  <div>

  </div>
{:else}
  <div>
    <p>Backend canister ID: {process.env.CANISTER_ID_BACKEND}</p>
    <p>Frontend canister ID: {process.env.CANISTER_ID_FRONTEND}</p>
    <p>
      Internet Identity canister ID: {process.env.CANISTER_ID_INTERNET_IDENTITY}
    </p>
  </div>
{/if}
<style>
  p {
    color: #666;
    font-size: 14px;
    margin: 0 0 8px;
  }
  div {
    margin-top: 30px;
  }
</style>
