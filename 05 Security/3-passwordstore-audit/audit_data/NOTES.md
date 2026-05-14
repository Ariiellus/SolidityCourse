# Notes

## Discover Findings

- L18: private variables are not privates
- L18: private variables are not private
- L26: Anyone can call this function. Not access control.

## Report


### [H-01] Storing the password onchain makes it visible to anyone

**Likelihood & Impact:** 
- Likelihood: High
- Impact: High
- Severity: High


**Description:** 
In L18, the variable s_password is not private. All data stored onchain is visible to anyone. The `s_password` variable is a private variable, but it is not really private.

**Impact:** 
Any user can view the password, which breaks the central ideal behind the contract.

**Proof of Concept:**

Create a local anvil chain. Deploy the contract and use the storage tool to get the output of the `s_password` variable.

`cast storage <contract_address> 1 --rpc-url http://localhost:8545`

For this example:

`cast storage 0x5FbDB2315678afecb367f032d93F642f64180aa3 1 --rpc-url http://localhost:8545`

Getting the output: `0x6d7950617373776f726400000000000000000000000000000000000000000014`

Which converted from hex to string using `cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014` we get `myPassword`.

**Recommended Mitigation:** 

The architecture of the contract must be changed in order to securely store a password onchain. An example is to encrypt the password offchain and store the encrypted password onchain.

### [H-02] Missing Access Control allows anyone to set the password

**Likelihood & Impact:** 
- Likelihood: High
- Impact: High
- Severity: High

**Description:** 
In L26, the function setPassword can be called by anyone. This is a security issue because it allows anyone to set the password.

**Impact:** 
Any user can set the password, which breaks the central ideal behind the contract.

**Proof of Concept:**

```solidity
    function test_anyone_can_set_password() public {
        vm.startPrank(address(1));
        string memory expectedPassword = "iGotAccess";
        passwordStore.setPassword(expectedPassword);

        vm.startPrank(owner);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword, expectedPassword);
        console.log("expectedPassword", actualPassword);
    }
```

**Recommended Mitigation:** 
```solidity
    function setPassword(string memory newPassword) external { // Anyone can call this function
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        s_password = newPassword;
        emit SetNetPassword();
    }
```

### [I-01] Incorrect NatSpec

**Likelihood & Impact:** 
- Likelihood: High
- Impact: None
- Severity: Informational

**Description:** 

```javascript
    /*
     * @notice This allows only the owner to retrieve the password.
@>   * @param newPassword The new password to set.
     */
     function getPassword() external view returns (string memory) {...}
 ```

 The `PasswordStore::getPassword` function signature is `getPassword()` while the NatSpec says it should be `getPassword(string)`.

 **Impact:** The NatSpec is incorrect.

 **Recommended Mitigation:** Remove the incorrect NatSpec line.

 ```diff
 -  * @param newPassword The new password to set.
 ```
