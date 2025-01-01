// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract SimpleStorage {
    uint256 myFavoriteNumber;

    // A struct is a custom data type that groups related variables
    struct Person {
        uint256 favoriteNumber;
        string name;
    }

    Person[] public listOfPeople;

    // mapping is like a dictionary, pairing a string with a uint256
    mapping(string => uint256) public nameToFavoriteNumber;

    function store(uint256 _favoriteNumber) public virtual {
        myFavoriteNumber = _favoriteNumber;
    }

    // retrieve can be: view, pure
    // A view function reads the state of the blockchain but does not modify it
    // A pure function neither reads nor modifies the blockchain state.

    function retrieve() public view returns (uint256) {
        return myFavoriteNumber;
    }

    // calldata: Temporary data passed into a function; cannot be modified.
    // memory: Temporary data stored during function execution; modifiable.
    // storage: Data stored permanently on the blockchain.

    function addPerson(string memory _name, uint256 _favoriteNumber) public {
        listOfPeople.push(Person(_favoriteNumber, _name));
    }
}
