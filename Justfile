set positional-arguments

build_dir_circom := "./build/circom"
build_dir_foundry := "./build/foundry"
verifier_dir := "./src/contracts/verifiers"

setup:
  asdf install
  yarn
  forge install
  just compile-foundry
  just test-foundry
  just circom-compile
  just test

test:
  yarn run test

circom-compile:
  just compile Hello

compile-foundry:
  forge build

test-foundry:
  forge test -vvv

clean:
 rm -rf {{build_dir_circom}}
 rm -rf {{build_dir_foundry}}
 rm -rf {{verifier_dir}}

#
# Circom compilation
#

@compile c: build-dir powers-of-tau
  echo -n Compiling {{c}}.circom...
  mkdir -p {{build_dir_circom}}/{{c}}
  circom src/circuits/{{c}}.circom --r1cs --wasm --sym --output {{build_dir_circom}}/{{c}} > /dev/null
  snarkjs r1cs info {{build_dir_circom}}/{{c}}/{{c}}.r1cs > /dev/null
  snarkjs groth16 setup {{build_dir_circom}}/{{c}}/{{c}}.r1cs {{powers_of_tau}} {{build_dir_circom}}/{{c}}/init.zkey > /dev/null
  snarkjs zkey contribute {{build_dir_circom}}/{{c}}/init.zkey {{build_dir_circom}}/{{c}}/final.zkey --name="1st Contributor Name" -v -e="random text" > /dev/null
  snarkjs zkey export verificationkey {{build_dir_circom}}/{{c}}/final.zkey {{build_dir_circom}}/{{c}}/verification_key.json > /dev/null
  snarkjs zkey export solidityverifier {{build_dir_circom}}/{{c}}/final.zkey {{verifier_dir}}/{{c}}Verifier.sol > /dev/null
  # TODO bump solidity version

  sed -i 's/pragma solidity .*;/pragma solidity ^0.8.0;/' {{verifier_dir}}/{{c}}Verifier.sol
  sed -i 's/contract Verifier/contract {{c}}Verifier/' {{verifier_dir}}/{{c}}Verifier.sol
  echo Done


#
# Powers of Tau setup
#
powers_of_tau_size := "10"
powers_of_tau_filename := "powersOfTau28_hez_final_" + powers_of_tau_size + ".ptau"
powers_of_tau_url := "https://hermez.s3-eu-west-1.amazonaws.com/" + powers_of_tau_filename
powers_of_tau := build_dir_circom + "/" + powers_of_tau_filename

@powers-of-tau: build-dir
  [ -f {{powers_of_tau}} ] || wget {{powers_of_tau_url}} -O {{powers_of_tau}}

@build-dir:
  mkdir -p build/circom src/contracts/verifiers
