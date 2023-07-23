// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {SismoConnect, SismoConnectHelper, SismoConnectVerifiedResult, AuthType, SismoConnectConfig} from "@sismo-core/sismo-connect-solidity/contracts/libs/SismoLib.sol";

contract DelegNouns is Context, ERC165, IERC1155MetadataURI, SismoConnect {
    using SismoConnectHelper for SismoConnectVerifiedResult;
    using Address for address;

    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    uint256 public totalTokenId = 0;
    // groupId => address delegate =>  => token id
    mapping(bytes16 => mapping(address => uint256)) public groupIdtToDelegateAddressToTokenId;
    // Base URI
    string private baseURI = "https://noun-api.com/beta/pfp";
    // Nouns Data
    uint256 public constant MAX_BACKGROUND = 2;
    uint256 public constant MAX_BODY = 29;
    uint256 public constant MAX_ACCESSORY = 136;
    uint256 public constant MAX_HEAD = 233;
    uint256 public constant MAX_GLASSES = 20;

    // Sismo data
    bytes16 private _appId = 0x9e6a23b6e64796a5d8aa82fde326f6ae;
    bool private _isTest = true;
    // vaultId => bool (already claimed)
    mapping(uint256 => bool) public claimed;

    //ERROR
    error DelegateForThisGroupIdAlreadyExist();
    error DelegateForThisGroupIdDoesNotExist();
    error AddressZero();
    error VaultAlreadyClaimed();

    //EVENTS
    event NewDelegateAddedForGroupId(bytes16 _groupId, address _delegate);

    constructor() IERC1155MetadataURI() SismoConnect(buildConfig(_appId, _isTest)) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId || super.supportsInterface(interfaceId);
    }

    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }

    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    //@notice This function return the URI of the token
    //@param id The id of the token
    //@return The URI of the token
    function uri(uint256 _tokenId) public view virtual override returns (string memory) {
        if (_tokenId > totalTokenId) revert("ERC1155Metadata: URI query for nonexistent token");
        (uint head, uint background, uint body, uint accessory, uint glasses) = _tokenIdToTraits(_tokenId);
        return string.concat(
            baseURI,
            "?head=",
            Strings.toString(head),
            "&background=",
            Strings.toString(background),
            "&body=",
            Strings.toString(body),
            "&accessory=",
            Strings.toString(accessory),
            "&glasses=",
            Strings.toString(glasses)
        );
    }

    function addNewDelegateForGroupId(bytes16 _groupId, address _delegate) public {
        if (_delegate == address(0)) revert AddressZero();
        if (groupIdtToDelegateAddressToTokenId[_groupId][_delegate] != 0) revert DelegateForThisGroupIdAlreadyExist();

        totalTokenId++;
        groupIdtToDelegateAddressToTokenId[_groupId][_delegate] = totalTokenId;

        emit NewDelegateAddedForGroupId(_groupId, _delegate);
    }

    //@notice return all the traits of a token
    //@param _tokenId The id of the token
    //@return head, background, body, accessory, glasses
    function _tokenIdToTraits(uint256 _tokenId) internal pure returns (uint256 head, uint256 background, uint256 body, uint256 accessory, uint256 glasses) {
        head = MAX_HEAD % _tokenId;
        background = MAX_BACKGROUND % _tokenId;
        body = MAX_BODY % _tokenId;
        accessory = MAX_ACCESSORY % _tokenId;
        glasses = MAX_GLASSES % _tokenId;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        emit TransferSingle(operator, from, to, id, amount);
        _afterTokenTransfer(operator, from, to, ids, amounts, data);
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");
        address operator = _msgSender();
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }
        emit TransferBatch(operator, from, to, ids, amounts);
        _afterTokenTransfer(operator, from, to, ids, amounts, data);
        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    function mint(bytes memory sismoConnectResponse, bytes16 _groupId, address delegate) public {
        if (groupIdtToDelegateAddressToTokenId[_groupId][delegate] == 0) revert DelegateForThisGroupIdDoesNotExist();


        SismoConnectVerifiedResult memory result = verify({
            responseBytes: sismoConnectResponse,
        // we want users to prove that they own a Sismo Vault
        // and that they are members of the group with the id 0x42c768bb8ae79e4c5c05d3b51a4ec74a
        // we are recreating the auth and claim requests made in the frontend to be sure that
        // the proofs provided in the response are valid with respect to this auth request
            auth: buildAuth({authType: AuthType.VAULT}),
            claim: buildClaim({groupId : APP_ID}),
            // we also want to check if the signed message provided in the response is the signature of the user's address
            signature : buildSignature({message : abi.encode(msg.sender)})
        });

        uint256 vaultId = SismoConnectHelper.getUserId(result, AuthType.VAULT);
        if (claimed[vaultId]) {
            revert VaultAlreadyClaimed();
        }
        claimed[vaultId] = true;

        uint256 _tokenId = groupIdtToDelegateAddressToTokenId[_groupId][delegate];

        _mint(msg.sender, _tokenId, 1, "");
    }

    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        if (to == address(0)) revert AddressZero();
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);
        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);
        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);
        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);
        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        emit TransferSingle(operator, from, address(0), id, amount);
        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        address operator = _msgSender();
        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }
        emit TransferBatch(operator, from, address(0), ids, amounts);
        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }
}
