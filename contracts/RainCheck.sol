// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RainCheck is ERC721Enumerable, Pausable, Ownable {
    address public _collection = 0x52b7571d4e7214a9c91dA6Ba9f1B893071Db273A;
    string public _BASEURI = "https://meta.raincheck.one/1/";  //Mian:1  Bsc:56  Rinkeby:4
    mapping(address => bool) public _whitelist;
    
    struct CheckInfo {
        mapping(string => address) addressInfo;
        mapping(string => uint256) valueInfo;
        mapping(string => bool) boolInfo;
        mapping(string => string) stringInfo;
    }
    mapping(uint256 => CheckInfo) _dataMap; //tokenid => CheckInfo
    
    
    //constructor
    //=========================================
    constructor(address delegate) ERC721("RainCheck", "RC") {
    }

    receive() external payable {
	}

    function _baseURI() override internal view returns (string memory) {
        return _BASEURI;
    }
    
    
    //set
    //=========================================
    function rainCheckSetPausable(bool pause) public onlyOwner {
        if (pause) {
            super._pause();
        } else {
            super._unpause();
        }
    }

    function rainCheckSetBaseURI(string calldata baseURI) public onlyOwner {
        _BASEURI = baseURI;
    }
    
    function rainCheckSetCollection(address collection) public onlyOwner {
        _collection = collection;
    }

    function rainCheckSetWhitelist(address key, bool value) public onlyOwner {
        _whitelist[key] = value;
    }
    
    //query
    //=========================================
    function rainCheckQueryAddress(uint256 tokenId, string memory key) public view returns(address) {
       CheckInfo storage info = _dataMap[tokenId];
       return info.addressInfo[key];
    }
    
    function rainCheckQueryValue(uint256 tokenId, string memory key) public view returns(uint256) {
       CheckInfo storage info = _dataMap[tokenId];
       return info.valueInfo[key];
    }
    
    function rainCheckQueryBool(uint256 tokenId, string memory key) public view returns(bool) {
       CheckInfo storage info = _dataMap[tokenId];
       return info.boolInfo[key];
    }

    function rainCheckQueryString(uint256 tokenId, string memory key) public view returns(string memory) {
       CheckInfo storage info = _dataMap[tokenId];
       return info.stringInfo[key];
    }
    
    function rainCheckQueryBalance() public view returns(uint) {
        return address(this).balance;
	}
    
    
    //rainCheck
    //=========================================
    function rainCheckStakeEth(address to, uint256 limitTime, uint256 fee, string memory memo) public payable whenNotPaused {
        uint256 total = msg.value;
        require(total > fee, "RainCheck: amount must be greater than 0");
        uint256 amount = total - fee;
        //require(to != address(0), "RainCheck: transfer to the zero address");
        
        //checkFee
        uint256 tempFee = amount/500;
        require(fee >= tempFee, "RainCheck: the handling fee is too low");

        //transfer
        if (fee > 0) {
            payable(_collection).transfer(fee);
        }
        
        
        //nft
        uint256 tokenId = super.totalSupply() + 1;
        super._mint(msg.sender, tokenId);

        
        //setInfo
        _dataMap[tokenId].addressInfo["from"] = msg.sender;
        _dataMap[tokenId].addressInfo["to"] = to;
        
        _dataMap[tokenId].valueInfo["amount"] = amount;
        _dataMap[tokenId].valueInfo["fee"] = fee;
        _dataMap[tokenId].valueInfo["stakeTime"] = block.timestamp;
        _dataMap[tokenId].valueInfo["limitTime"] = limitTime;
        
        _dataMap[tokenId].boolInfo["isEth"] = true;
        _dataMap[tokenId].stringInfo["memo"] = memo;
    }
    
    function rainCheckStakeErc20(address erc20Address, uint256 total, address to, uint256 limitTime, uint256 fee, string memory memo) public whenNotPaused {
        require(total > fee, "RainCheck: amount must be greater than 0");
        uint256 amount = total - fee;
        //require(to != address(0), "RainCheck: transfer to the zero address");
        IERC20 erc20 = IERC20(erc20Address);

        //checkFee
        uint256 tempFee = amount/500;
        require(fee >= tempFee, "RainCheck: the handling fee is too low");

        //transfer
        if (fee > 0) {
            bool feeSuccess = erc20.transferFrom(msg.sender, _collection, fee);
            require(feeSuccess, "RainCheck: transfer fee failed");
        }
        bool transferSuccess = erc20.transferFrom(msg.sender, address(this), amount);
        require(transferSuccess, "RainCheck: transfer failed");
        

        //nft
        uint256 tokenId = super.totalSupply() + 1;
        super._mint(msg.sender, tokenId);
        
        //setInfo
        _dataMap[tokenId].addressInfo["erc20"] = erc20Address;
        _dataMap[tokenId].addressInfo["from"] = msg.sender;
        _dataMap[tokenId].addressInfo["to"] = to;
        
        _dataMap[tokenId].valueInfo["amount"] = amount;
        _dataMap[tokenId].valueInfo["fee"] = fee;
        _dataMap[tokenId].valueInfo["stakeTime"] = block.timestamp;
        _dataMap[tokenId].valueInfo["limitTime"] = limitTime;
        
        _dataMap[tokenId].boolInfo["isErc20"] = true;
        _dataMap[tokenId].stringInfo["memo"] = memo;
    }
    
    function rainCheckWithdraw(uint256 tokenId) public whenNotPaused {
        address tokenOwner = super.ownerOf(tokenId);
        require(tokenOwner == msg.sender, "RainCheck: this token doesn't belong to you");
        
        CheckInfo storage info = _dataMap[tokenId];
        require(info.valueInfo["amount"] > 0, "RainCheck: this token is already been exchanged");
        require(block.timestamp > (info.valueInfo["stakeTime"] + info.valueInfo["limitTime"]), "RainCheck: It's not yet the agreed time");
        
        //amount & to
        uint256 amount = info.valueInfo["amount"];
        info.valueInfo["amount"] = 0;
        address to = info.addressInfo["to"];
        if (to == address(0)) {
            to = msg.sender;
        }

        //withdraw
        if (info.boolInfo["isErc20"]) {
            IERC20 erc20 = IERC20(info.addressInfo["erc20"]);
            bool transferSuccess = erc20.transfer(to, amount);
            require(transferSuccess, "RainCheck: transfer fail");
            return;
        }
        
        if (info.boolInfo["isEth"]) {
            payable(to).transfer(amount);
            return;
        }
    }
    
    function rainCheckVoid(uint256 tokenId) public whenNotPaused {
        address tokenOwner = super.ownerOf(tokenId);
        require(tokenOwner == msg.sender, "RainCheck: this token doesn't belong to you");
        
        CheckInfo storage info = _dataMap[tokenId];
        require(info.valueInfo["amount"] > 0, "RainCheck: this token is already been exchanged");
        
        //amount & to
        uint256 amount = info.valueInfo["amount"];
        info.valueInfo["amount"] = 0;
        address to = info.addressInfo["from"];

        //Void
        if (info.boolInfo["isErc20"]) {
            IERC20 erc20 = IERC20(info.addressInfo["erc20"]);
            bool transferSuccess = erc20.transfer(to, amount);
            require(transferSuccess, "RainCheck: transfer fail");
            return;
        }
        
        if (info.boolInfo["isEth"]) {
            payable(to).transfer(amount);
            return;
        }
    }
    
}