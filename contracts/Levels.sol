// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

error NotAdmin();

contract Levels is OwnableUpgradeable, UUPSUpgradeable {
    
    mapping(address => uint64) private levels;
    mapping(address => bool) private admins;
    address[] private adminsList;

    event SetLevel(address to, uint256 level);
    
    constructor() {
            _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
    function initialize() public initializer {
        admins[msg.sender] = true;
        adminsList.push(msg.sender);
        __Ownable_init();
    }

    modifier isAdmin() {
        if (!admins[msg.sender]) revert NotAdmin();
        _;
    }

    function getLevel(address who) public view returns (uint64) {
        return levels[who];
    }

    //Adming functions
    function setLevel(address to, uint64 _level) public isAdmin {
        levels[to] = _level;
        emit SetLevel(to, _level);
    }

    function setAdmin(address admin, bool status) public onlyOwner {
        if (status == true && !admins[admin]) {
            adminsList.push(admin);
        } else if (admins[admin] && !status) {
            for (uint i = 0; i < adminsList.length; i++) {
                if (adminsList[i] == admin) {
                    delete adminsList[i];
                    break;
                }
            }

        } else if (admins[admin] && status) {
            return;
        }
        admins[admin] = status;
    }

    function ifAdmin(address account) public view returns (bool) {
        return admins[account];
    }
    
    function getAdminsList() public view onlyOwner returns (address[] memory) {
        return adminsList;
    }
}
