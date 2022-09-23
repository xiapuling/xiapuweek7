//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

//Console functions to help debug the smart contract just like in Javascript
import "hardhat/console.sol";
//OpenZeppelin's NFT Standard Contracts. We will extend functions from this in our implementation
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract NFTMarketplace is ERC721URIStorage, ERC2981 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    address payable owner;
    uint256 public listPrice = 0.00001 ether;
    uint96 public royaltyFee = 1000; // 10%

    struct ListedToken {
        uint256 tokenId;
        address owner;
        uint256 price;
        bool currentlyListed;
    }

    event TokenListedSuccess (
        uint256 indexed tokenId,
        address owner,
        uint256 price,
        bool currentlyListed
    );

    mapping(uint256 => ListedToken) private idToListedToken;

    constructor() ERC721("NFTMarketplace", "NFTM") {
        owner = payable(msg.sender);
        _setDefaultRoyalty(msg.sender, 100);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721, ERC2981) returns (bool) {
      return super.supportsInterface(interfaceId);
    }

    function createToken(string memory tokenURI, uint256 price) public payable returns (uint) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createListedToken(newTokenId, price);

        _setTokenRoyalty(newTokenId, msg.sender, royaltyFee);

        return newTokenId;
    }

    function createListedToken(uint256 _tokenId, uint256 _price) private {
        require(msg.value == listPrice, "Not enough funds passed for listing!");
        require(_price > 0, "Price is zero or negative");

        idToListedToken[_tokenId] = ListedToken({
            tokenId: _tokenId,
            owner: msg.sender,
            price: _price,
            currentlyListed: true
        });

        emit TokenListedSuccess(_tokenId, msg.sender, _price, true);
    }

    function getNFTs(address _owner) public view returns (ListedToken[] memory) {
        uint tokenCount = _tokenIds.current();
        uint ownedTokenCount = 0;
        uint currentIndex = 0; // we can't push to memory array, so we use this

        ListedToken[] memory tokens = new ListedToken[](0); // to create memory arrays with not hardcoded length

        if (_owner != address(0)) {
            for (uint i = 1; i <= tokenCount; i++) {
                ListedToken memory token = idToListedToken[i];
                if (token.owner == _owner) {
                    ownedTokenCount++;
                }
            }
            if (ownedTokenCount != 0) {
                tokens = new ListedToken[](ownedTokenCount);
                for (uint i = 1; i <= tokenCount; i++) {
                    ListedToken memory token = idToListedToken[i];
                    if (token.owner == _owner) {
                        tokens[currentIndex] = token;
                        currentIndex++;
                    }
                }
            }
        }

        return tokens;
    }

    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint tokenCount = _tokenIds.current();
        uint currentIndex = 0;

        ListedToken[] memory tokens = new ListedToken[](tokenCount);
        if (tokenCount != 0) {
            for (uint i = 1; i <= tokenCount; i++) {
                ListedToken memory token = idToListedToken[i];
                tokens[currentIndex] = token;
                currentIndex++;
            }
        }
        return tokens;
    }

    function getMyNFTs() public view returns (ListedToken[] memory) {
        return getNFTs(msg.sender);
    }

    function executeSale(uint256 tokenId) public payable {
        require(msg.value > 0, "You cant pay zero");  

        ListedToken memory token = idToListedToken[tokenId];

        require(token.currentlyListed == true, "Token must be listed for executing sales!");

        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(tokenId, token.price);  

        require(msg.value == token.price + royaltyAmount + listPrice, "Not enough funds paid to execute sale");

        (bool sentToRoyaltyReceiver,) = payable(royaltyReceiver).call{value: royaltyAmount}("");
        require(sentToRoyaltyReceiver, "Transaction to the royalty receiver has failed");
        
        (bool sentToCreator,) = payable(owner).call{value: listPrice}("");
        require(sentToCreator, "Transaction to the contract creator has failed");

        (bool sentToOwner,) = payable(token.owner).call{value: msg.value - listPrice - royaltyAmount}("");
        require(sentToOwner, "Transaction to the token owner has failed");

        _transfer(token.owner, msg.sender, tokenId);
        approve(address(this), tokenId);

        idToListedToken[tokenId].owner = msg.sender;
        idToListedToken[tokenId].currentlyListed = false;

        _itemsSold.increment();
    }

    function listExistingNFT(uint256 tokenId) public onlyTokenOwner(tokenId) {
        idToListedToken[tokenId].currentlyListed = true;
    }

    function unlistExistingNFT(uint256 tokenId) public onlyTokenOwner(tokenId) {
        idToListedToken[tokenId].currentlyListed = false;
    }

    function updateListPrice(uint256 _listPrice) public payable onlyContractOwner {
        listPrice = _listPrice;
    }

    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

    function getListedTokenForId(uint256 tokenId) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getCurrentTokenId() public view returns (uint256) {
        return _tokenIds.current();
    }

    function getLatestIdToListedToken() public view returns (ListedToken memory) {
        return getListedTokenForId(getCurrentTokenId());
    }

    modifier onlyContractOwner() {
        require(owner == msg.sender, "Only contract owner can invoke this operation");
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Only token owner can invoke this operation");
        _;
    }
}
