// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../contracts/INFT.sol";

contract ERC721Token is ERC721, ERC721URIStorage, ERC721Enumerable {
    string private _baseUri;

    constructor(string memory baseUri) ERC721("Mock Token", "USDT") {
        _setBaseURI(baseUri);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(_from, _to, _tokenId, _batchSize);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public virtual override(ERC721, IERC721) {
        super.safeTransferFrom(_from, _to, _tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "caller is not owner nor approved"
        );
        _burn(tokenId);
    }

    function safeMint(
        address to,
        string memory tokenUri
    ) public returns (uint256) {
        uint256 tokenId = totalSupply() + 1;
        require(tokenId > 0, "tokenId must be a number");
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenUri);
        return tokenId;
    }

    function approve_(
        address to,
        uint256 tokenId
    ) public virtual returns (bool) {
        approve(to, tokenId);
        return true;
    }

    function setTokenURI(uint256 tokenId, string memory newTokenURI) external {
        super._setTokenURI(tokenId, newTokenURI);
    }

    function _setBaseURI(string memory baseUri) internal {
        _baseUri = baseUri;
    }
}
