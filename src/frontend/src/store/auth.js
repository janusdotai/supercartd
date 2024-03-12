import { writable } from "svelte/store";
import { idlFactory } from "../../../declarations/backend/service.did.js";
import { Actor, HttpAgent } from "@dfinity/agent";

/**
 * Creates an actor for the Backend canister
 *
 * @param {{agentOptions: import("@dfinity/agent").HttpAgentOptions, actorOptions: import("@dfinity/agent").ActorConfig}} options
 * @returns {import("@dfinity/agent").ActorSubclass<import("../../../declarations/backend/backend.did")._SERVICE>}
 */
export function createActor(options) {
  //console.log("ICP ACTOR CREATED")
  const hostOptions = {
    host:
      process.env.DFX_NETWORK === "ic"
        ? `https://${process.env.CANISTER_ID_BACKEND}.ic0.app`
        : undefined,
  };
  if (!options) {
    options = {
      agentOptions: hostOptions,
    };
  } else if (!options.agentOptions) {
    options.agentOptions = hostOptions;
  } else {
    options.agentOptions.host = hostOptions.host;
  }  
  
  const agent = new HttpAgent({ ...options.agentOptions });
  // Fetch root key for certificate validation during development
  if (process.env.DFX_NETWORK !== "ic") {
    //console.log("I'm fetching a new local root key")
    agent.fetchRootKey().catch((err) => {
      console.warn(
        "Unable to fetch root key. Check to ensure that your local replica is running"
      );
      console.error(err);
    });
  }

  // Creates an actor with using the candid interface and the HttpAgent
  return Actor.createActor(idlFactory, {
    agent,
    canisterId: process.env.CANISTER_ID_BACKEND,
    ...options?.actorOptions,
  });
};

export const IS_PRODUCTION = process.env.DFX_NETWORK === "ic" ? true : false;

//global internet computer interface
export const auth = writable({
  loggedIn: false,
  actor: createActor(),
});

//user sesion info
export const user = writable({
  name: "n/a",
  created_at: Math.round(new Date().getTime() / 1000, 2),
  updated_at: Math.round(new Date().getTime() / 1000, 2),
  principal: "",
  account: "",
  chain_id: 0,
  most_recent_wallet: "",
  //theme: localStorage.getItem('picoPreferredColorScheme') ?? ""
});

//user token
export const token = writable(localStorage.getItem('scdtoken'));
