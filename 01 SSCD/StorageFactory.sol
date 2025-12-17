// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18; 

import {SimpleStorage} from "./SimpleStorage.sol";

    // Notice the difference between SimpleStorage and simpleStorage. Solidity is key sensitive
    // For security reasons, it is better to not use a similar name
    // changing simpleStorage to newSimpleStorage 
    
contract StorageFactory {

    SimpleStorage[] public listOfSimpleStorageContracts;

    function createSimpleStorageContract() public {
        SimpleStorage newSimpleStorage = new SimpleStorage();
        listOfSimpleStorageContracts.push(newSimpleStorage);
    }
    
    function sfStore(uint256 _simpleStorageIndex, uint256 _newSimpleStorageNumber) public {
        // To interact with this function I'll need the address and the ABI (Application Binary Interface)

        // Instead of:

        // SimpleStorage mySimpleStorage = listOfSimpleStorageContracts[_simpleStorageIndex];
        // mySimpleStorage.store(_newSimpleStorageNumber);

        // We can also do this:

        listOfSimpleStorageContracts[_simpleStorageIndex].store(_newSimpleStorageNumber);
    }

    function sfGet(uint256 _simpleStorageIndex) public view returns(uint256){
        // Instead of:
        
        //SimpleStorage mySimpleStorage = listOfSimpleStorageContracts[_simpleStorageIndex];
        // return mySimpleStorage.retrieve();

        // We can also do this:

        return listOfSimpleStorageContracts[_simpleStorageIndex].retrieve();
    }
}