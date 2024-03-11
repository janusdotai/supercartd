import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Prim "mo:⛔";
import Float "mo:base/Float";
import Int64 "mo:base/Int64";
import Error "mo:base/Error";
import Map "mo:map/Map";
import Sha256 "mo:sha2/Sha256";
import HttpTypes "http/http.types";
import Hex "Hex";
import Types "Types";
import Random "mo:base/Random";
import { JSON; Candid; } "mo:serde";


module {

    // public let MICROSECOND = 1_000;
	// public let MILLISECOND = 1_000_000;
	// public let SECOND = 1_000_000_000;
	// public let MINUTE = 60_000_000_000;
	// public let HOUR = 3_600_000_000_000;
	// public let DAY = 86_400_000_000_000;
	// public let WEEK = 604_800_000_000_000;
    
    public func now() : Nat64 {
        let now = Nat64.fromNat(Int.abs(Time.now()));
        return now;
    };

    public func now_ms() : Nat64 {
        let n = now();
        let ms = n / 1_000_000;
        return ms;
    };

    public func now_seconds() : Nat64 {
        let n = now();
        let s = n / 1_000_000_000;
        return s;
    };    
    
    //https://forum.dfinity.org/t/subtext-substring-function-in-motoko/11838
    public func subString(t : Text, i : Nat, j : Nat) : Text {
        let size = t.size();
        if (i == 0 and j == size) return t;
        assert (j <= size);
        let cs = t.chars();
        var r = "";
        var n = i;
        while (n > 0) {
            ignore cs.next();
            n -= 1;
        };
        n := j;
        while (n > 0) {
            switch (cs.next()) {
                case null { assert false };
                case (?c) { r #= Prim.charToText(c) }
            };
            n -= 1;
        };
        return r;
    };
    

    //https://forum.dfinity.org/t/motokos-type-system-converting-between-types/1957/10
    public func textToNat(t : Text) : ?Nat {
        var n : Nat = 0;
        for (c in t.chars()) {
            if (Char.isDigit(c)) {
                let charAsNat : Nat = Nat32.toNat(Char.toNat32(c) - 48);
                n := n * 10 + charAsNat;
            } else {
                return null;
            };
        };
        return Option.make(n);
    };

    //https://forum.dfinity.org/t/how-to-convert-text-to-float/15982
    public func textToFloat(t : Text) : async Float {
        var i : Float = 1;
        var f : Float = 0;
        var isDecimal : Bool = false;
        for (c in t.chars()) {
            if (Char.isDigit(c)) {
                let charToNat : Nat64 = Nat64.fromNat(Nat32.toNat(Char.toNat32(c) -48));
                let natToFloat : Float = Float.fromInt64(Int64.fromNat64(charToNat));
                if (isDecimal) {
                    let n : Float = natToFloat / Float.pow(10, i);
                    f := f + n;
                } else {
                    f := f * 10 + natToFloat;
                };
                i := i + 1;
            } else {
                if (Char.equal(c, '.') or Char.equal(c, ',')) {
                    f := f / Float.pow(10, i); // Force decimal
                    f := f * Float.pow(10, i); // Correction
                    isDecimal := true;
                    i := 1;
                } else {
                    throw Error.reject("NaN");
                };
            };
        };
        return f;
    };
   

    //https://github.com/aviate-labs/encoding.mo/blob/main/test/util.mo
    public func arrayToText(xs : [Nat8]) : Text {
        Text.fromIter(Iter.fromArray(
            Array.map<Nat8, Char>(
                xs,
                func (n : Nat8) : Char {
                    Char.fromNat32(Nat32.fromNat(Nat8.toNat(n)))
                },
            ),
        ));
    };
    
    public func textToArray(t : Text) : [Nat8] {
        Array.map<Char, Nat8>(
            Iter.toArray(t.chars()),
            func (c : Char) : Nat8 {
                Nat8.fromNat(Nat32.toNat(Char.toNat32(c)));
            },
        );
    };

    public func generateSha(t : Text) : Text {
        let x = Blob.toArray(Text.encodeUtf8(t));
        let sha = Sha256.fromArray(#sha256, x);
        let hash = Hex.encode(Blob.toArray(sha));
        return hash;
    };

    public func textToSha(t : Text) : Text {
        if(Text.size(t) < 10){
            Debug.trap("why so smol");
        };
        let x = Blob.toArray(Text.encodeUtf8(t));
        let sha = Sha256.fromArray(#sha256, x);
        let hash = Hex.encode(Blob.toArray(sha));
        return hash;
    };

    public func averageFloats(arr: [Float], ignore_zeros : Bool): Float {
        if (Array.size(arr) == 0) {
            return 0.0; 
        };        
        var sum = 0.0;       
        var candidates : [Float] = arr;
        if(ignore_zeros){
            candidates := Array.filter<Float>(arr, func(x) = x > 0);
        };        
        let length = Float.fromInt(Array.size(candidates));        
        if(length == 0){
            return 0.0
        };
        for(this_float in candidates.vals()){          
            sum := Float.add(sum, this_float);            
        };        
        let avg = sum / length;        
        return avg;
    };
   

    public func convertWei(w : Text) : ?Nat {
        switch(w){            
            case("wei"){
                return ?1;
            };
            case("kwei"){
                return ?1_000;
            };
            case("mwei"){
                return ?1_000_000;
            };
            case("gwei"){
                return ?1_000_000_000;
            };
            case("ether" or "eth"){
                return ?1_000_000_000_000_000_000; //1 ether equaling 10^18 wei.
            };
            case(_){
                return null;
            };
        };
    };

    //todo when querying chain which provider do you like 
    public func randomProvider() : async Text { 
         let providers = [ 
            "https://eth.llamarpc.com",
            "https://rpc.flashbots.net",
            "https://cloudflare-eth.com",
            "https://ethereum.publicnode.com"
        ]; //ipv6 only
       
        //todo: nice to have, call a cost effective VRF?
        // var size = Nat8.fromNat(providers.siz    e());
        // var b = await Random.blob();
        // var r = Random.rangeFrom(size, b);
        // Debug.print("random was called RESULT: " # debug_show(r));
        
        return providers[0];
    };


    public func convertStringToE8s_new(value : Text ) : Int {
        var thing = convertStringToE8s(value);
        switch(thing){
            case(#ok(result)){
                return result;
            };
            case(_){
                return 0;
            };
        };
    };   

    // Function to convert string to e8s - chatgpt + dimi
    public func convertStringToE8s(value: Text): Result.Result<Int, Text> {
        //Debug.print("convertStringToE8s " # debug_show(value));
        var integral = "";
        var fractional = "";

        var parts = Iter.toArray(Text.split(value, #char '.'));
        if(parts.size() == 2){
            integral := parts[0];
            fractional := parts[1];
        };

        //Debug.print("convertStringToE8s " # debug_show(integral));
        //Debug.print("convertStringToE8s " # debug_show(fractional));
       
        let E8S_PER_TOKEN = 100_000_000;
        var e8s = 0;

        if (Text.size(integral) > 0) {
            let integralBigInt = Option.get(Nat.fromText(integral), 0);
            e8s += Nat.mul(integralBigInt, E8S_PER_TOKEN);
        };

        let fracSize = Text.size(fractional);
        if (fracSize > 0) {
            if (fracSize > 8) {                
                return #err "invalid";
            };

            //Debug.print("early fractional " # debug_show(fractional));
            //Debug.print("early fractional " # debug_show(fracSize));

            let start = fracSize;            
            let end = 7; //end at 8

            let iter = Iter.range(start, end);
            for(thing in iter){
                fractional := Text.concat(fractional, "0");
            };

            if(fractional.size() != 8){                
                return #err "invalid fracational size";
            };
            let fractionalBigInt = Option.get(Nat.fromText(fractional), 0);            
            e8s += fractionalBigInt;
        };

        return #ok(e8s);
    };


};