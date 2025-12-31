// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script} from "@forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedUserOp(
        bytes memory callData,
        HelperConfig.NetworkConfig memory networkConfig,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // Generate the unsiged data

        uint256 nonce = IEntryPoint(networkConfig.entryPoint).getNonce(minimalAccount, 0);

        PackedUserOperation memory unsignedUserOp = _generateUnsignedUserOp(callData, minimalAccount, nonce);

        // Get the userOp hash
        bytes32 userOpHash = IEntryPoint(networkConfig.entryPoint).getUserOpHash(unsignedUserOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // Return the signed data
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 anvilDefaultKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(anvilDefaultKey, digest);
        } else {
            (v, r, s) = vm.sign(networkConfig.account, digest);
        }
        unsignedUserOp.signature = abi.encodePacked(r, s, v);

        return unsignedUserOp;
    }

    function _generateUnsignedUserOp(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = 256;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
