pragma solidity ^0.4.18;
import './ByteArr.sol';
import './ERC725.sol';

contract KeyHolder is ERC725 {
    using ByteArr for bytes32[];
    using ByteArr for bytes;

    uint256 nonce;

    mapping (bytes32 => Key) keys;
    mapping (uint256 => bytes32[]) keysByPurpose;
    mapping (uint256 => Execution) executions;

    function KeyHolder() {
        bytes32 _key = keccak256(msg.sender);
        keys[_key].key = _key;
        keys[_key].purposes = [1];
        keys[_key].keyType = 1;
        keysByPurpose[1].push(_key);
    }

    function addKey(bytes32 _key, uint256[] _purposes, uint256 _type) internal returns (bool success) {
        require(keys[_key].key != _key);

        keys[_key].key = _key;
        keys[_key].purposes = _purposes;
        keys[_key].keyType = _type;

        for (uint i = 0; i < _purposes.length; i++) {
            keysByPurpose[_purposes[i]].push(_key);
        }

        KeyAdded(_key, _purposes, _type);
        return true;
    }

    function removeKey(bytes32 _key) internal returns (bool success) {
        require(keys[_key].key == _key);
        KeyRemoved(keys[_key].key, keys[_key].purposes, keys[_key].keyType);

        for (uint i = 0; i < keys[_key].purposes.length; i++) {
            var (index, isThere) = keysByPurpose[keys[_key].purposes[i]].indexOf(_key);
            keysByPurpose[keys[_key].purposes[i]].removeByIndex(index);
        }

        delete keys[_key];

        return true;
    }
    function execute(address _to, uint256 _value, bytes _data) public returns (uint256 executionId) {
        executions[nonce].to = _to;
        executions[nonce].value = _value;
        executions[nonce].data = _data;
        nonce++;
        return nonce-1;
    }

    // 	"a820f50a": "addKey(bytes32,uint256[],uint256)",
    // 	"747442d3": "approve(uint256,bool)",
    // 	"b61d27f6": "execute(address,uint256,bytes)",
    // 	"862642f5": "removeKey(bytes32)"

    function approve(uint256 _id, bool _approve) public returns (bool success) {
        address to = executions[_id].to;
        bytes4 fHash = executions[_id].data.getFuncHash();
        if (to == address(this)) {
            if (fHash == 0xa820f50a || fHash == 0x862642f5) {
                require(hasRight(keccak256(msg.sender),1));
            } else {
                require(hasRight(keccak256(msg.sender),2));
            }
        } else {
            require(hasRight(keccak256(msg.sender),1) || hasRight(keccak256(msg.sender),2));
        }

        Approved(_id, _approve);

        if (_approve == true) {
            executions[_id].approved = true;
            success = executions[_id].to.call(executions[_id].data,0);
            if (success) {
                executions[_id].executed = true;
                Executed(_id, executions[_id].to, executions[_id].value, executions[_id].data);
                return;
            } else {
                return;
            }
        } else {
            executions[_id].approved = false;
        }
        return true;
    }

    // WARN: Deviates from ERC725
    function getKey(bytes32 _key) public view returns(uint256[] purposes, uint256 keyType, bytes32 key){
        require(keys[_key].key == _key);
        return (keys[_key].purposes, keys[_key].keyType, keys[_key].key);
    }

    function getKeyPurposes(bytes32 _key) public view returns(uint256[] purpose) {
        require(keys[_key].key == _key);
        return keys[_key].purposes;
    }

    function getKeysByPurpose(uint256 _purpose) public view returns(bytes32[] _keys) {
        return keysByPurpose[_purpose];
    }

    function hasRight(bytes32 _key, uint256 _purpose) view internal returns(bool result) {
        var (index,isThere) = keysByPurpose[_purpose].indexOf(_key);
        return isThere;
    }
}
