pragma solidity ^0.8.19;
interface IERC721Burnable {
    function burn(uint256 tokenId) external;
}
interface IERC721MetaTx {
    function nonces(address signer) external view returns (uint256);
    function getDomainSeparator() external view returns (bytes32);
}
interface ILensHubEventHooks {
    function emitUnfollowedEvent(uint256 unfollowerProfileId, uint256 idOfProfileUnfollowed) external;
}
interface ILensImplGetters {
    function getFollowNFTImpl() external view returns (address);
    function getCollectNFTImpl() external view returns (address);
}
library Errors {
    error CannotInitImplementation();
    error Initialized();
    error SignatureExpired();
    error SignatureInvalid();
    error InvalidOwner();
    error NotOwnerOrApproved();
    error NotHub();
    error TokenDoesNotExist();
    error NotGovernance();
    error NotGovernanceOrEmergencyAdmin();
    error EmergencyAdminCanOnlyPauseFurther();
    error NotProfileOwner();
    error PublicationDoesNotExist();
    error ProfileImageURILengthInvalid();
    error CallerNotFollowNFT();
    error CallerNotCollectNFT();  
    error ArrayMismatch();
    error NotWhitelisted();
    error InvalidParameter();
    error ExecutorInvalid();
    error Blocked();
    error SelfBlock();
    error NotFollowing();
    error SelfFollow();
    error InvalidReferrer();
    error InvalidPointedPub();
    error NonERC721ReceiverImplementer();
    error AlreadyEnabled();
    error MaxActionModuleIdReached();  
    error InitParamsInvalid();
    error ActionNotAllowed();
    error CollectNotAllowed();  
    error Paused();
    error PublishingPaused();
    error GuardianEnabled();
    error NotEOA();
    error DisablingAlreadyTriggered();
}
library Typehash {
    bytes32 constant ACT = keccak256('Act(uint256 publicationActedProfileId,uint256 publicationActedId,uint256 actorProfileId,uint256[] referrerProfileIds,uint256[] referrerPubIds,address actionModuleAddress,bytes actionModuleData,uint256 nonce,uint256 deadline)');
    bytes32 constant BURN = keccak256('Burn(uint256 tokenId,uint256 nonce,uint256 deadline)');
    bytes32 constant CHANGE_DELEGATED_EXECUTORS_CONFIG = keccak256('ChangeDelegatedExecutorsConfig(uint256 delegatorProfileId,address[] delegatedExecutors,bool[] approvals,uint64 configNumber,bool switchToGivenConfig,uint256 nonce,uint256 deadline)');
    bytes32 constant LEGACY_COLLECT = keccak256('Collect(uint256 publicationCollectedProfileId,uint256 publicationCollectedId,uint256 collectorProfileId,uint256 referrerProfileId,uint256 referrerPubId,bytes collectModuleData,uint256 nonce,uint256 deadline)');
    bytes32 constant COMMENT = keccak256('Comment(uint256 profileId,string contentURI,uint256 pointedProfileId,uint256 pointedPubId,uint256[] referrerProfileIds,uint256[] referrerPubIds,bytes referenceModuleData,address collectModule,bytes collectModuleInitData,address referenceModule,bytes referenceModuleInitData,uint256 nonce,uint256 deadline)');
    bytes32 constant EIP712_DOMAIN = keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');
    bytes32 constant FOLLOW = keccak256('Follow(uint256 followerProfileId,uint256[] idsOfProfilesToFollow,uint256[] followTokenIds,bytes[] datas,uint256 nonce,uint256 deadline)');
    bytes32 constant MIRROR = keccak256('Mirror(uint256 profileId,uint256 pointedProfileId,uint256 pointedPubId,uint256[] referrerProfileId,uint256[] referrerPubId,bytes referenceModuleData,uint256 nonce,uint256 deadline)');
    bytes32 constant POST = keccak256('Post(uint256 profileId,string contentURI,address collectModule,bytes collectModuleInitData,address referenceModule,bytes referenceModuleInitData,uint256 nonce,uint256 deadline)');
    bytes32 constant QUOTE = keccak256('Quote(uint256 profileId,string contentURI,uint256 pointedProfileId,uint256 pointedPubId,uint256[] referrerProfileIds,uint256[] referrerPubIds,bytes referenceModuleData,address collectModule,bytes collectModuleInitData,address referenceModule,bytes referenceModuleInitData,uint256 nonce,uint256 deadline)');
    bytes32 constant SET_BLOCK_STATUS = keccak256('SetBlockStatus(uint256 byProfileId,uint256[] idsOfProfilesToSetBlockStatus,bool[] blockStatus,uint256 nonce,uint256 deadline)');
    bytes32 constant SET_FOLLOW_MODULE = keccak256('SetFollowModule(uint256 profileId,address followModule,bytes followModuleInitData,uint256 nonce,uint256 deadline)');
    bytes32 constant SET_PROFILE_IMAGE_URI = keccak256('SetProfileImageURI(uint256 profileId,string imageURI,uint256 nonce,uint256 deadline)');
    bytes32 constant SET_PROFILE_METADATA_URI = keccak256('SetProfileMetadataURI(uint256 profileId,string metadata,uint256 nonce,uint256 deadline)');
    bytes32 constant UNFOLLOW = keccak256('Unfollow(uint256 unfollowerProfileId,uint256[] idsOfProfilesToUnfollow,uint256 nonce,uint256 deadline)');
}
library Types {
    struct TokenData {
        address owner;
        uint96 mintTimestamp;
    }
    struct FollowData {
        uint160 followerProfileId;
        uint48 originalFollowTimestamp;
        uint48 followTimestamp;
        uint256 profileIdAllowedToRecover;
    }
    enum ProtocolState {
        Unpaused,
        PublishingPaused,
        Paused
    }
    enum PublicationType {
        Nonexistent,
        Post,
        Comment,
        Mirror,
        Quote
    }
    struct EIP712Signature {
        address signer;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
    }
    struct Profile {
        uint256 pubCount;  
        address followModule;  
        address followNFT;  
        string __DEPRECATED__handle;  
        string imageURI;  
        string __DEPRECATED__followNFTURI;  
        string metadataURI;  
    }
    struct Publication {
        uint256 pointedProfileId;
        uint256 pointedPubId;
        string contentURI;
        address referenceModule;
        address __DEPRECATED__collectModule;  
        address __DEPRECATED__collectNFT;  
        PublicationType pubType;
        uint256 rootProfileId;
        uint256 rootPubId;
        uint256 enabledActionModulesBitmap;  
    }
    struct CreateProfileParams {
        address to;
        string imageURI;
        address followModule;
        bytes followModuleInitData;
    }
    struct PostParams {
        uint256 profileId;
        string contentURI;
        address[] actionModules;
        bytes[] actionModulesInitDatas;
        address referenceModule;
        bytes referenceModuleInitData;
    }
    struct CommentParams {
        uint256 profileId;
        string contentURI;
        uint256 pointedProfileId;
        uint256 pointedPubId;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        bytes referenceModuleData;
        address[] actionModules;
        bytes[] actionModulesInitDatas;
        address referenceModule;
        bytes referenceModuleInitData;
    }
    struct QuoteParams {
        uint256 profileId;
        string contentURI;
        uint256 pointedProfileId;
        uint256 pointedPubId;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        bytes referenceModuleData;
        address[] actionModules;
        bytes[] actionModulesInitDatas;
        address referenceModule;
        bytes referenceModuleInitData;
    }
    struct ReferencePubParams {
        uint256 profileId;
        string contentURI;
        uint256 pointedProfileId;
        uint256 pointedPubId;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        bytes referenceModuleData;
        address[] actionModules;
        bytes[] actionModulesInitDatas;
        address referenceModule;
        bytes referenceModuleInitData;
    }
    struct MirrorParams {
        uint256 profileId;
        uint256 pointedProfileId;
        uint256 pointedPubId;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        bytes referenceModuleData;
    }
    struct CollectParams {
        uint256 publicationCollectedProfileId;
        uint256 publicationCollectedId;
        uint256 collectorProfileId;
        uint256 referrerProfileId;
        uint256 referrerPubId;
        bytes collectModuleData;
    }
    struct PublicationActionParams {
        uint256 publicationActedProfileId;
        uint256 publicationActedId;
        uint256 actorProfileId;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        address actionModuleAddress;
        bytes actionModuleData;
    }
    struct ProcessActionParams {
        uint256 publicationActedProfileId;
        uint256 publicationActedId;
        uint256 actorProfileId;
        address actorProfileOwner;
        address transactionExecutor;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        Types.PublicationType[] referrerPubTypes;
        bytes actionModuleData;
    }
    struct ProcessCollectParams {
        uint256 publicationCollectedProfileId;
        uint256 publicationCollectedId;
        uint256 collectorProfileId;
        address collectorProfileOwner;
        address transactionExecutor;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        Types.PublicationType[] referrerPubTypes;
        bytes data;
    }
    struct ProcessCommentParams {
        uint256 profileId;
        address transactionExecutor;
        uint256 pointedProfileId;
        uint256 pointedPubId;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        Types.PublicationType[] referrerPubTypes;
        bytes data;
    }
    struct ProcessQuoteParams {
        uint256 profileId;
        address transactionExecutor;
        uint256 pointedProfileId;
        uint256 pointedPubId;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        Types.PublicationType[] referrerPubTypes;
        bytes data;
    }
    struct ProcessMirrorParams {
        uint256 profileId;
        address transactionExecutor;
        uint256 pointedProfileId;
        uint256 pointedPubId;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        Types.PublicationType[] referrerPubTypes;
        bytes data;
    }
    struct DelegatedExecutorsConfig {
        mapping(uint256 => mapping(address => bool)) isApproved;  
        uint64 configNumber;
        uint64 prevConfigNumber;
        uint64 maxConfigNumberSet;
    }
    struct ActionModuleWhitelistData {
        uint248 id;
        bool isWhitelisted;
    }
}
library TokenURIMainFontLib {
    function getFontName() internal pure returns (string memory) {
        return 'Ginto Nord';
    }
    function getFontBase64Encoded() external pure returns (string memory) {
        return
            '@font-face{font-family:"Ginto Nord";src:url(data:application/font-woff;charset=utf-8;base64,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) format("woff"); font-weight:normal;font-style:normal;}';
    }
}
library TokenURISecondaryFontLib {
    function getFontName() internal pure returns (string memory) {
        return 'Ginto';
    }
    function getFontBase64Encoded() external pure returns (string memory) {
        return
            '@font-face{font-family:"Ginto";src:url(data:application/font-woff;charset=utf-8;base64,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) format("woff"); font-weight:normal;font-style:normal;}';
    }
}
interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}
interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }
    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        if (returndata.length > 0) {
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}
library Base64 {
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";
        string memory table = _TABLE;
        string memory result = new string(4 * ((data.length + 2) / 3));
        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {
            } {
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)  
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)  
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)  
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)  
            }
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }
        return result;
    }
}
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
library Math {
    enum Rounding {
        Down,  
        Up,  
        Zero  
    }
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a & b) + (a ^ b) / 2;
    }
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return a == 0 ? 0 : (a - 1) / b + 1;
    }
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0;  
            uint256 prod1;  
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }
            if (prod1 == 0) {
                return prod0 / denominator;
            }
            require(denominator > prod1);
            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;
            uint256 inverse = (3 * denominator) ^ 2;
            inverse *= 2 - denominator * inverse;  
            inverse *= 2 - denominator * inverse;  
            inverse *= 2 - denominator * inverse;  
            inverse *= 2 - denominator * inverse;  
            inverse *= 2 - denominator * inverse;  
            inverse *= 2 - denominator * inverse;  
            result = prod0 * inverse;
            return result;
        }
    }
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 result = 1 << (log2(a) >> 1);
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}
abstract contract HubRestricted {
    address public immutable HUB;
    modifier onlyHub() {
        if (msg.sender != HUB) {
            revert Errors.NotHub();
        }
        _;
    }
    constructor(address hub) {
        HUB = hub;
    }
}
interface IERC721Timestamped {
    function mintTimestampOf(uint256 tokenId) external view returns (uint256);
    function tokenDataOf(uint256 tokenId) external view returns (Types.TokenData memory);
    function exists(uint256 tokenId) external view returns (bool);
    function totalSupply() external view returns (uint256);
}
interface IFollowNFT {
    error AlreadyFollowing();
    error NotFollowing();
    error FollowTokenDoesNotExist();
    error AlreadyWrapped();
    error OnlyWrappedFollowTokens();
    error DoesNotHavePermissions();
    function initialize(uint256 profileId) external;
    function follow(
        uint256 followerProfileId,
        address transactionExecutor,
        uint256 followTokenId
    ) external returns (uint256);
    function unfollow(uint256 unfollowerProfileId, address transactionExecutor) external;
    function removeFollower(uint256 followTokenId) external;
    function approveFollow(uint256 approvedProfileId, uint256 followTokenId) external;
    function wrap(uint256 followTokenId) external;
    function wrap(uint256 followTokenId, address wrappedTokenReceiver) external;
    function unwrap(uint256 followTokenId) external;
    function processBlock(uint256 followerProfileId) external returns (bool);
    function getFollowerProfileId(uint256 followTokenId) external view returns (uint256);
    function getOriginalFollowTimestamp(uint256 followTokenId) external view returns (uint256);
    function getFollowTimestamp(uint256 followTokenId) external view returns (uint256);
    function getProfileIdAllowedToRecover(uint256 followTokenId) external view returns (uint256);
    function getFollowData(uint256 followTokenId) external view returns (Types.FollowData memory);
    function isFollowing(uint256 followerProfileId) external view returns (bool);
    function getFollowTokenId(uint256 followerProfileId) external view returns (uint256);
    function getFollowApproved(uint256 followTokenId) external view returns (uint256);
    function getFollowerCount() external view returns (uint256);
}
interface ILensGovernable {
    function setGovernance(address newGovernance) external;
    function setEmergencyAdmin(address newEmergencyAdmin) external;
    function setState(Types.ProtocolState newState) external;
    function whitelistProfileCreator(address profileCreator, bool whitelist) external;
    function whitelistFollowModule(address followModule, bool whitelist) external;
    function whitelistReferenceModule(address referenceModule, bool whitelist) external;
    function whitelistActionModule(address actionModule, bool whitelist) external;
    function getGovernance() external view returns (address);
    function getState() external view returns (Types.ProtocolState);
    function isProfileCreatorWhitelisted(address profileCreator) external view returns (bool);
    function isFollowModuleWhitelisted(address followModule) external view returns (bool);
    function isReferenceModuleWhitelisted(address referenceModule) external view returns (bool);
    function getActionModuleWhitelistData(address actionModule)
        external
        view
        returns (Types.ActionModuleWhitelistData memory);
}
interface ILensProtocol {
    function createProfile(Types.CreateProfileParams calldata createProfileParams) external returns (uint256);
    function setProfileMetadataURI(uint256 profileId, string calldata metadataURI) external;
    function setProfileMetadataURIWithSig(
        uint256 profileId,
        string calldata metadataURI,
        Types.EIP712Signature calldata signature
    ) external;
    function setFollowModule(
        uint256 profileId,
        address followModule,
        bytes calldata followModuleInitData
    ) external;
    function setFollowModuleWithSig(
        uint256 profileId,
        address followModule,
        bytes calldata followModuleInitData,
        Types.EIP712Signature calldata signature
    ) external;
    function changeDelegatedExecutorsConfig(
        uint256 delegatorProfileId,
        address[] calldata delegatedExecutors,
        bool[] calldata approvals,
        uint64 configNumber,
        bool switchToGivenConfig
    ) external;
    function changeDelegatedExecutorsConfig(
        uint256 delegatorProfileId,
        address[] calldata delegatedExecutors,
        bool[] calldata approvals
    ) external;
    function changeDelegatedExecutorsConfigWithSig(
        uint256 delegatorProfileId,
        address[] calldata delegatedExecutors,
        bool[] calldata approvals,
        uint64 configNumber,
        bool switchToGivenConfig,
        Types.EIP712Signature calldata signature
    ) external;
    function setProfileImageURI(uint256 profileId, string calldata imageURI) external;
    function setProfileImageURIWithSig(
        uint256 profileId,
        string calldata imageURI,
        Types.EIP712Signature calldata signature
    ) external;
    function post(Types.PostParams calldata postParams) external returns (uint256);
    function postWithSig(Types.PostParams calldata postParams, Types.EIP712Signature calldata signature)
        external
        returns (uint256);
    function comment(Types.CommentParams calldata commentParams) external returns (uint256);
    function commentWithSig(Types.CommentParams calldata commentParams, Types.EIP712Signature calldata signature)
        external
        returns (uint256);
    function mirror(Types.MirrorParams calldata mirrorParams) external returns (uint256);
    function mirrorWithSig(Types.MirrorParams calldata mirrorParams, Types.EIP712Signature calldata signature)
        external
        returns (uint256);
    function quote(Types.QuoteParams calldata quoteParams) external returns (uint256);
    function quoteWithSig(Types.QuoteParams calldata quoteParams, Types.EIP712Signature calldata signature)
        external
        returns (uint256);
    function follow(
        uint256 followerProfileId,
        uint256[] calldata idsOfProfilesToFollow,
        uint256[] calldata followTokenIds,
        bytes[] calldata datas
    ) external returns (uint256[] memory);
    function followWithSig(
        uint256 followerProfileId,
        uint256[] calldata idsOfProfilesToFollow,
        uint256[] calldata followTokenIds,
        bytes[] calldata datas,
        Types.EIP712Signature calldata signature
    ) external returns (uint256[] memory);
    function unfollow(uint256 unfollowerProfileId, uint256[] calldata idsOfProfilesToUnfollow) external;
    function unfollowWithSig(
        uint256 unfollowerProfileId,
        uint256[] calldata idsOfProfilesToUnfollow,
        Types.EIP712Signature calldata signature
    ) external;
    function setBlockStatus(
        uint256 byProfileId,
        uint256[] calldata idsOfProfilesToSetBlockStatus,
        bool[] calldata blockStatus
    ) external;
    function setBlockStatusWithSig(
        uint256 byProfileId,
        uint256[] calldata idsOfProfilesToSetBlockStatus,
        bool[] calldata blockStatus,
        Types.EIP712Signature calldata signature
    ) external;
    function collect(Types.CollectParams calldata collectParams) external returns (uint256);
    function collectWithSig(Types.CollectParams calldata collectParams, Types.EIP712Signature calldata signature)
        external
        returns (uint256);
    function act(Types.PublicationActionParams calldata publicationActionParams) external returns (bytes memory);
    function actWithSig(
        Types.PublicationActionParams calldata publicationActionParams,
        Types.EIP712Signature calldata signature
    ) external returns (bytes memory);
    function isFollowing(uint256 followerProfileId, uint256 followedProfileId) external view returns (bool);
    function isDelegatedExecutorApproved(
        uint256 delegatorProfileId,
        address delegatedExecutor,
        uint64 configNumber
    ) external view returns (bool);
    function isDelegatedExecutorApproved(uint256 delegatorProfileId, address delegatedExecutor)
        external
        view
        returns (bool);
    function getDelegatedExecutorsConfigNumber(uint256 delegatorProfileId) external view returns (uint64);
    function getDelegatedExecutorsPrevConfigNumber(uint256 delegatorProfileId) external view returns (uint64);
    function getDelegatedExecutorsMaxConfigNumberSet(uint256 delegatorProfileId) external view returns (uint64);
    function isBlocked(uint256 profileId, uint256 byProfileId) external view returns (bool);
    function getActionModuleById(uint256 id) external view returns (address);
    function getContentURI(uint256 profileId, uint256 pubId) external view returns (string memory);
    function getProfile(uint256 profileId) external view returns (Types.Profile memory);
    function getPublication(uint256 profileId, uint256 pubId) external view returns (Types.Publication memory);
    function getPublicationType(uint256 profileId, uint256 pubId) external view returns (Types.PublicationType);
}
interface IERC2981 is IERC165 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}
interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}
abstract contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}
library StorageLib {
    uint256 constant TOKEN_DATA_MAPPING_SLOT = 2;
    uint256 constant SIG_NONCES_MAPPING_SLOT = 10;
    uint256 constant LAST_INITIALIZED_REVISION_SLOT = 11;  
    uint256 constant PROTOCOL_STATE_SLOT = 12;
    uint256 constant PROFILE_CREATOR_WHITELIST_MAPPING_SLOT = 13;
    uint256 constant FOLLOW_MODULE_WHITELIST_MAPPING_SLOT = 14;
    uint256 constant ACTION_MODULE_WHITELIST_DATA_MAPPING_SLOT = 15;
    uint256 constant REFERENCE_MODULE_WHITELIST_MAPPING_SLOT = 16;
    uint256 constant PROFILE_ID_BY_HANDLE_HASH_MAPPING_SLOT = 18;  
    uint256 constant PROFILES_MAPPING_SLOT = 19;
    uint256 constant PUBLICATIONS_MAPPING_SLOT = 20;
    uint256 constant PROFILE_COUNTER_SLOT = 22;
    uint256 constant GOVERNANCE_SLOT = 23;
    uint256 constant EMERGENCY_ADMIN_SLOT = 24;
    uint256 constant TOKEN_GUARDIAN_DISABLING_TIMESTAMP_MAPPING_SLOT = 25;
    uint256 constant DELEGATED_EXECUTOR_CONFIG_MAPPING_SLOT = 26;
    uint256 constant BLOCKED_STATUS_MAPPING_SLOT = 27;
    uint256 constant ACTION_MODULES_SLOT = 28;
    uint256 constant MAX_ACTION_MODULE_ID_USED_SLOT = 29;
    uint256 constant PROFILE_ROYALTIES_BPS_SLOT = 30;
    uint256 constant MAX_ACTION_MODULE_ID_SUPPORTED = 255;
    function getPublication(uint256 profileId, uint256 pubId)
        internal
        pure
        returns (Types.Publication storage _publication)
    {
        assembly {
            mstore(0, profileId)
            mstore(32, PUBLICATIONS_MAPPING_SLOT)
            mstore(32, keccak256(0, 64))
            mstore(0, pubId)
            _publication.slot := keccak256(0, 64)
        }
    }
    function getProfile(uint256 profileId) internal pure returns (Types.Profile storage _profiles) {
        assembly {
            mstore(0, profileId)
            mstore(32, PROFILES_MAPPING_SLOT)
            _profiles.slot := keccak256(0, 64)
        }
    }
    function getDelegatedExecutorsConfig(uint256 delegatorProfileId)
        internal
        pure
        returns (Types.DelegatedExecutorsConfig storage _delegatedExecutorsConfig)
    {
        assembly {
            mstore(0, delegatorProfileId)
            mstore(32, DELEGATED_EXECUTOR_CONFIG_MAPPING_SLOT)
            _delegatedExecutorsConfig.slot := keccak256(0, 64)
        }
    }
    function tokenGuardianDisablingTimestamp()
        internal
        pure
        returns (mapping(address => uint256) storage _tokenGuardianDisablingTimestamp)
    {
        assembly {
            _tokenGuardianDisablingTimestamp.slot := TOKEN_GUARDIAN_DISABLING_TIMESTAMP_MAPPING_SLOT
        }
    }
    function getTokenData(uint256 tokenId) internal pure returns (Types.TokenData storage _tokenData) {
        assembly {
            mstore(0, tokenId)
            mstore(32, TOKEN_DATA_MAPPING_SLOT)
            _tokenData.slot := keccak256(0, 64)
        }
    }
    function blockedStatus(uint256 blockerProfileId)
        internal
        pure
        returns (mapping(uint256 => bool) storage _blockedStatus)
    {
        assembly {
            mstore(0, blockerProfileId)
            mstore(32, BLOCKED_STATUS_MAPPING_SLOT)
            _blockedStatus.slot := keccak256(0, 64)
        }
    }
    function nonces() internal pure returns (mapping(address => uint256) storage _nonces) {
        assembly {
            _nonces.slot := SIG_NONCES_MAPPING_SLOT
        }
    }
    function profileIdByHandleHash()
        internal
        pure
        returns (mapping(bytes32 => uint256) storage _profileIdByHandleHash)
    {
        assembly {
            _profileIdByHandleHash.slot := PROFILE_ID_BY_HANDLE_HASH_MAPPING_SLOT
        }
    }
    function profileCreatorWhitelisted()
        internal
        pure
        returns (mapping(address => bool) storage _profileCreatorWhitelisted)
    {
        assembly {
            _profileCreatorWhitelisted.slot := PROFILE_CREATOR_WHITELIST_MAPPING_SLOT
        }
    }
    function followModuleWhitelisted()
        internal
        pure
        returns (mapping(address => bool) storage _followModuleWhitelisted)
    {
        assembly {
            _followModuleWhitelisted.slot := FOLLOW_MODULE_WHITELIST_MAPPING_SLOT
        }
    }
    function actionModuleWhitelistData()
        internal
        pure
        returns (mapping(address => Types.ActionModuleWhitelistData) storage _actionModuleWhitelistData)
    {
        assembly {
            _actionModuleWhitelistData.slot := ACTION_MODULE_WHITELIST_DATA_MAPPING_SLOT
        }
    }
    function actionModuleById() internal pure returns (mapping(uint256 => address) storage _actionModules) {
        assembly {
            _actionModules.slot := ACTION_MODULES_SLOT
        }
    }
    function incrementMaxActionModuleIdUsed() internal returns (uint256) {
        uint256 incrementedId;
        assembly {
            incrementedId := add(sload(MAX_ACTION_MODULE_ID_USED_SLOT), 1)
            sstore(MAX_ACTION_MODULE_ID_USED_SLOT, incrementedId)
        }
        if (incrementedId > MAX_ACTION_MODULE_ID_SUPPORTED) {
            revert Errors.MaxActionModuleIdReached();
        }
        return incrementedId;
    }
    function referenceModuleWhitelisted()
        internal
        pure
        returns (mapping(address => bool) storage _referenceModuleWhitelisted)
    {
        assembly {
            _referenceModuleWhitelisted.slot := REFERENCE_MODULE_WHITELIST_MAPPING_SLOT
        }
    }
    function getGovernance() internal view returns (address _governance) {
        assembly {
            _governance := sload(GOVERNANCE_SLOT)
        }
    }
    function setGovernance(address newGovernance) internal {
        assembly {
            sstore(GOVERNANCE_SLOT, newGovernance)
        }
    }
    function getEmergencyAdmin() internal view returns (address _emergencyAdmin) {
        assembly {
            _emergencyAdmin := sload(EMERGENCY_ADMIN_SLOT)
        }
    }
    function setEmergencyAdmin(address newEmergencyAdmin) internal {
        assembly {
            sstore(EMERGENCY_ADMIN_SLOT, newEmergencyAdmin)
        }
    }
    function getState() internal view returns (Types.ProtocolState _state) {
        assembly {
            _state := sload(PROTOCOL_STATE_SLOT)
        }
    }
    function setState(Types.ProtocolState newState) internal {
        assembly {
            sstore(PROTOCOL_STATE_SLOT, newState)
        }
    }
    function getLastInitializedRevision() internal view returns (uint256 _lastInitializedRevision) {
        assembly {
            _lastInitializedRevision := sload(LAST_INITIALIZED_REVISION_SLOT)
        }
    }
    function setLastInitializedRevision(uint256 newLastInitializedRevision) internal {
        assembly {
            sstore(LAST_INITIALIZED_REVISION_SLOT, newLastInitializedRevision)
        }
    }
}
interface IERC721Metadata is IERC721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
abstract contract ERC2981CollectionRoyalties is IERC2981 {
    uint16 internal constant BASIS_POINTS = 10000;
    bytes4 internal constant INTERFACE_ID_ERC2981 = 0x2a55205a;
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == INTERFACE_ID_ERC2981 || interfaceId == type(IERC165).interfaceId;
    }
    function setRoyalty(uint256 royaltiesInBasisPoints) external {
        _beforeRoyaltiesSet(royaltiesInBasisPoints);
        _setRoyalty(royaltiesInBasisPoints);
    }
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address, uint256) {
        return (_getReceiver(tokenId), _getRoyaltyAmount(tokenId, salePrice));
    }
    function _setRoyalty(uint256 royaltiesInBasisPoints) internal virtual {
        if (royaltiesInBasisPoints > BASIS_POINTS) {
            revert Errors.InvalidParameter();
        } else {
            _storeRoyaltiesInBasisPoints(royaltiesInBasisPoints);
        }
    }
    function _getRoyaltyAmount(
        uint256,  
        uint256 salePrice
    ) internal view virtual returns (uint256) {
        return (salePrice * _loadRoyaltiesInBasisPoints()) / BASIS_POINTS;
    }
    function _storeRoyaltiesInBasisPoints(uint256 royaltiesInBasisPoints) internal virtual {
        uint256 royaltiesInBasisPointsSlot = _getRoyaltiesInBasisPointsSlot();
        assembly {
            sstore(royaltiesInBasisPointsSlot, royaltiesInBasisPoints)
        }
    }
    function _loadRoyaltiesInBasisPoints() internal view virtual returns (uint256) {
        uint256 royaltiesInBasisPointsSlot = _getRoyaltiesInBasisPointsSlot();
        uint256 royaltyAmount;
        assembly {
            royaltyAmount := sload(royaltiesInBasisPointsSlot)
        }
        return royaltyAmount;
    }
    function _beforeRoyaltiesSet(uint256 royaltiesInBasisPoints) internal view virtual;
    function _getRoyaltiesInBasisPointsSlot() internal view virtual returns (uint256);
    function _getReceiver(uint256 tokenId) internal view virtual returns (address);
}
library FollowTokenURILib {
    using Strings for uint96;
    using Strings for uint256;
    function getTokenURI(
        uint256 followTokenId,
        uint256 followedProfileId,
        uint256 originalFollowTimestamp
    ) external pure returns (string memory) {
        string memory followTokenIdAsString = followTokenId.toString();
        string memory followedProfileIdAsString = followedProfileId.toString();
        return
            string(
                abi.encodePacked(
                    'data:application/json;base64,',
                    Base64.encode(
                        abi.encodePacked(
                            '{"name":"Follower #',
                            followTokenIdAsString,
                            '","description":"Lens Protocol - Follower #',
                            followTokenIdAsString,
                            ' of Profile #',
                            followedProfileIdAsString,
                            '","image":"data:image/svg+xml;base64,',
                            _getSVGImageBase64Encoded(followTokenIdAsString, followedProfileIdAsString),
                            '","attributes":[{"display_type": "number", "trait_type":"ID","value":"',
                            followTokenIdAsString,
                            '"},{"trait_type":"DIGITS","value":"',
                            bytes(followTokenIdAsString).length.toString(),
                            '"},{"trait_type":"MINTED AT","value":"',
                            originalFollowTimestamp.toString(),
                            '"}]}'
                        )
                    )
                )
            );
    }
    function _getSVGImageBase64Encoded(string memory followTokenIdAsString, string memory followedProfileIdAsString)
        private
        pure
        returns (string memory)
    {
        return
            Base64.encode(
                abi.encodePacked(
                    '<svg width="724" height="724" viewBox="0 0 724 724" fill="none" xmlns="http://www.w3.org/2000/svg"><defs><style>',
                    TokenURIMainFontLib.getFontBase64Encoded(),
                    '</style></defs><defs><style>',
                    TokenURISecondaryFontLib.getFontBase64Encoded(),
                    '</style></defs><g clip-path="url(#clip0_2600_6938)"><rect width="724" height="724" fill="#D0DBFF"/><rect x="91" y="290" width="543" height="144" rx="72" fill="#FFEBB8"/><text fill="#5A4E4C" font-family="',
                    TokenURIMainFontLib.getFontName(),
                    '" font-size="42" letter-spacing="-1.5px"><tspan x="278" y="393.182">#',
                    followTokenIdAsString,
                    '</tspan></text><text fill="#5A4E4C" fill-opacity="0.7" font-family="',
                    TokenURISecondaryFontLib.getFontName(),
                    '" font-size="26" letter-spacing="-0.2px"><tspan x="280" y="347.516">Following #',
                    followedProfileIdAsString,
                    '</tspan></text><path d="M215.667 344.257C215.188 344.745 214.736 345.238 214.275 345.726C214.275 345.051 214.316 344.358 214.316 343.692C214.316 343.026 214.316 342.291 214.284 341.598C213.498 312.801 170.5 312.801 169.714 341.598C169.696 342.291 169.687 342.989 169.687 343.692C169.687 344.381 169.709 345.06 169.727 345.726C169.275 345.238 168.823 344.745 168.335 344.257C167.847 343.769 167.341 343.272 166.844 342.798C146.095 322.996 115.712 353.709 135.326 374.606C135.802 375.11 136.285 375.612 136.776 376.111C160.444 400 191.999 400 191.999 400C191.999 400 223.558 400 247.226 376.111C247.72 375.615 248.203 375.113 248.676 374.606C268.291 353.686 237.889 322.996 217.158 342.798C216.657 343.272 216.146 343.76 215.667 344.257Z" fill="#5A4E4C" fill-opacity="0.25"/><path d="M210.278 365.9C209.551 365.9 208.843 365.955 208.16 366.059C209.851 366.926 211.01 368.698 211.01 370.744C211.01 373.644 208.682 375.994 205.809 375.994C202.936 375.994 200.607 373.644 200.607 370.744C200.607 370.57 200.615 370.397 200.632 370.227C199.34 371.836 198.602 373.763 198.602 375.773H194.984C194.984 368.089 202.084 362.282 210.278 362.282C218.473 362.282 225.573 368.089 225.573 375.773H221.955C221.955 370.557 216.98 365.9 210.278 365.9ZM164.129 370.069C162.678 371.738 161.841 373.784 161.841 375.925H158.223C158.223 368.236 165.324 362.434 173.518 362.434C181.712 362.434 188.813 368.236 188.813 375.925H185.195C185.195 370.705 180.22 366.052 173.518 366.052C172.937 366.052 172.369 366.087 171.816 366.154C173.411 367.051 174.49 368.77 174.49 370.744C174.49 373.644 172.161 375.994 169.288 375.994C166.415 375.994 164.086 373.644 164.086 370.744C164.086 370.515 164.101 370.29 164.129 370.069ZM198.866 381.969C197.72 384.073 195.135 385.701 191.985 385.701C188.829 385.701 186.251 384.09 185.107 381.974L181.924 383.694C183.764 387.098 187.64 389.319 191.985 389.319C196.338 389.319 200.207 387.07 202.043 383.7L198.866 381.969Z" fill="#5A4E4C"/></g><defs><clipPath id="clip0_2600_6938"><rect width="724" height="724" fill="white"/></clipPath></defs></svg>'
                )
            );
    }
}
interface ILensERC721 is IERC721, IERC721Timestamped, IERC721Burnable, IERC721MetaTx, IERC721Metadata {}
interface ILensProfiles is ILensERC721 {
    function DANGER__disableTokenGuardian() external;
    function enableTokenGuardian() external;
    function getTokenGuardianDisablingTimestamp(address wallet) external view returns (uint256);
}
library MetaTxLib {
    string constant EIP712_DOMAIN_VERSION = '2';
    bytes32 constant EIP712_DOMAIN_VERSION_HASH = keccak256(bytes(EIP712_DOMAIN_VERSION));
    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;
    bytes32 constant LENS_HUB_CACHED_POLYGON_DOMAIN_SEPARATOR =
        0xbf9544cf7d7a0338fc4f071be35409a61e51e9caef559305410ad74e16a05f2d;
    address constant LENS_HUB_ADDRESS = 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d;
    function validateSetProfileMetadataURISignature(
        Types.EIP712Signature calldata signature,
        uint256 profileId,
        string calldata metadataURI
    ) external {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.SET_PROFILE_METADATA_URI,
                        profileId,
                        keccak256(bytes(metadataURI)),
                        _getAndIncrementNonce(signature.signer),
                        signature.deadline
                    )
                )
            ),
            signature
        );
    }
    function validateSetFollowModuleSignature(
        Types.EIP712Signature calldata signature,
        uint256 profileId,
        address followModule,
        bytes calldata followModuleInitData
    ) external {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.SET_FOLLOW_MODULE,
                        profileId,
                        followModule,
                        keccak256(followModuleInitData),
                        _getAndIncrementNonce(signature.signer),
                        signature.deadline
                    )
                )
            ),
            signature
        );
    }
    function validateChangeDelegatedExecutorsConfigSignature(
        Types.EIP712Signature calldata signature,
        uint256 delegatorProfileId,
        address[] calldata delegatedExecutors,
        bool[] calldata approvals,
        uint64 configNumber,
        bool switchToGivenConfig
    ) external {
        uint256 nonce = _getAndIncrementNonce(signature.signer);
        uint256 deadline = signature.deadline;
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.CHANGE_DELEGATED_EXECUTORS_CONFIG,
                        delegatorProfileId,
                        abi.encodePacked(delegatedExecutors),
                        abi.encodePacked(approvals),
                        configNumber,
                        switchToGivenConfig,
                        nonce,
                        deadline
                    )
                )
            ),
            signature
        );
    }
    function validateSetProfileImageURISignature(
        Types.EIP712Signature calldata signature,
        uint256 profileId,
        string calldata imageURI
    ) external {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.SET_PROFILE_IMAGE_URI,
                        profileId,
                        keccak256(bytes(imageURI)),
                        _getAndIncrementNonce(signature.signer),
                        signature.deadline
                    )
                )
            ),
            signature
        );
    }
    function validatePostSignature(Types.EIP712Signature calldata signature, Types.PostParams calldata postParams)
        external
    {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.POST,
                        postParams.profileId,
                        keccak256(bytes(postParams.contentURI)),
                        postParams.actionModules,
                        _hashActionModulesInitDatas(postParams.actionModulesInitDatas),
                        postParams.referenceModule,
                        keccak256(postParams.referenceModuleInitData),
                        _getAndIncrementNonce(signature.signer),
                        signature.deadline
                    )
                )
            ),
            signature
        );
    }
    function _hashActionModulesInitDatas(bytes[] memory actionModulesInitDatas) private pure returns (bytes32) {
        bytes32[] memory actionModulesInitDatasHashes = new bytes32[](actionModulesInitDatas.length);
        uint256 i;
        while (i < actionModulesInitDatas.length) {
            actionModulesInitDatasHashes[i] = keccak256(abi.encode(actionModulesInitDatas[i]));
            unchecked {
                ++i;
            }
        }
        return keccak256(abi.encodePacked(actionModulesInitDatasHashes));
    }
    struct ReferenceParamsForAbiEncode {
        bytes32 typehash;
        uint256 profileId;
        bytes32 contentURIHash;
        uint256 pointedProfileId;
        uint256 pointedPubId;
        uint256[] referrerProfileIds;
        uint256[] referrerPubIds;
        bytes32 referenceModuleDataHash;
        address[] actionModules;
        bytes32 actionModulesInitDataHash;
        address referenceModule;
        bytes32 referenceModuleInitDataHash;
        uint256 nonce;
        uint256 deadline;
    }
    function _abiEncode(ReferenceParamsForAbiEncode memory referenceParamsForAbiEncode)
        private
        pure
        returns (bytes memory)
    {
        bytes memory encodedStruct = abi.encode(referenceParamsForAbiEncode);
        assembly {
            let lengthWithoutOffset := sub(mload(encodedStruct), 32)  
            encodedStruct := add(encodedStruct, 32)  
            mstore(encodedStruct, lengthWithoutOffset)  
        }
        return encodedStruct;
    }
    function validateCommentSignature(
        Types.EIP712Signature calldata signature,
        Types.CommentParams calldata commentParams
    ) external {
        bytes32 contentURIHash = keccak256(bytes(commentParams.contentURI));
        bytes32 referenceModuleDataHash = keccak256(commentParams.referenceModuleData);
        bytes32 actionModulesInitDataHash = _hashActionModulesInitDatas(commentParams.actionModulesInitDatas);
        bytes32 referenceModuleInitDataHash = keccak256(commentParams.referenceModuleInitData);
        uint256 nonce = _getAndIncrementNonce(signature.signer);
        uint256 deadline = signature.deadline;
        bytes memory encodedAbi = _abiEncode(
            ReferenceParamsForAbiEncode(
                Typehash.COMMENT,
                commentParams.profileId,
                contentURIHash,
                commentParams.pointedProfileId,
                commentParams.pointedPubId,
                commentParams.referrerProfileIds,
                commentParams.referrerPubIds,
                referenceModuleDataHash,
                commentParams.actionModules,
                actionModulesInitDataHash,
                commentParams.referenceModule,
                referenceModuleInitDataHash,
                nonce,
                deadline
            )
        );
        _validateRecoveredAddress(_calculateDigest(keccak256(encodedAbi)), signature);
    }
    function validateQuoteSignature(Types.EIP712Signature calldata signature, Types.QuoteParams calldata quoteParams)
        external
    {
        bytes32 contentURIHash = keccak256(bytes(quoteParams.contentURI));
        bytes32 referenceModuleDataHash = keccak256(quoteParams.referenceModuleData);
        bytes32 actionModulesInitDataHash = _hashActionModulesInitDatas(quoteParams.actionModulesInitDatas);
        bytes32 referenceModuleInitDataHash = keccak256(quoteParams.referenceModuleInitData);
        uint256 nonce = _getAndIncrementNonce(signature.signer);
        uint256 deadline = signature.deadline;
        bytes memory encodedAbi = _abiEncode(
            ReferenceParamsForAbiEncode(
                Typehash.QUOTE,
                quoteParams.profileId,
                contentURIHash,
                quoteParams.pointedProfileId,
                quoteParams.pointedPubId,
                quoteParams.referrerProfileIds,
                quoteParams.referrerPubIds,
                referenceModuleDataHash,
                quoteParams.actionModules,
                actionModulesInitDataHash,
                quoteParams.referenceModule,
                referenceModuleInitDataHash,
                nonce,
                deadline
            )
        );
        _validateRecoveredAddress(_calculateDigest(keccak256(encodedAbi)), signature);
    }
    function validateMirrorSignature(Types.EIP712Signature calldata signature, Types.MirrorParams calldata mirrorParams)
        external
    {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.MIRROR,
                        mirrorParams.profileId,
                        mirrorParams.pointedProfileId,
                        mirrorParams.pointedPubId,
                        mirrorParams.referrerProfileIds,
                        mirrorParams.referrerPubIds,
                        keccak256(mirrorParams.referenceModuleData),
                        _getAndIncrementNonce(signature.signer),
                        signature.deadline
                    )
                )
            ),
            signature
        );
    }
    function validateBurnSignature(Types.EIP712Signature calldata signature, uint256 tokenId) external {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(Typehash.BURN, tokenId, _getAndIncrementNonce(signature.signer), signature.deadline)
                )
            ),
            signature
        );
    }
    function validateFollowSignature(
        Types.EIP712Signature calldata signature,
        uint256 followerProfileId,
        uint256[] calldata idsOfProfilesToFollow,
        uint256[] calldata followTokenIds,
        bytes[] calldata datas
    ) external {
        uint256 dataLength = datas.length;
        bytes32[] memory dataHashes = new bytes32[](dataLength);
        uint256 i;
        while (i < dataLength) {
            dataHashes[i] = keccak256(datas[i]);
            unchecked {
                ++i;
            }
        }
        uint256 nonce = _getAndIncrementNonce(signature.signer);
        uint256 deadline = signature.deadline;
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.FOLLOW,
                        followerProfileId,
                        keccak256(abi.encodePacked(idsOfProfilesToFollow)),
                        keccak256(abi.encodePacked(followTokenIds)),
                        keccak256(abi.encodePacked(dataHashes)),
                        nonce,
                        deadline
                    )
                )
            ),
            signature
        );
    }
    function validateUnfollowSignature(
        Types.EIP712Signature calldata signature,
        uint256 unfollowerProfileId,
        uint256[] calldata idsOfProfilesToUnfollow
    ) external {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.UNFOLLOW,
                        unfollowerProfileId,
                        keccak256(abi.encodePacked(idsOfProfilesToUnfollow)),
                        _getAndIncrementNonce(signature.signer),
                        signature.deadline
                    )
                )
            ),
            signature
        );
    }
    function validateSetBlockStatusSignature(
        Types.EIP712Signature calldata signature,
        uint256 byProfileId,
        uint256[] calldata idsOfProfilesToSetBlockStatus,
        bool[] calldata blockStatus
    ) external {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.SET_BLOCK_STATUS,
                        byProfileId,
                        keccak256(abi.encodePacked(idsOfProfilesToSetBlockStatus)),
                        keccak256(abi.encodePacked(blockStatus)),
                        _getAndIncrementNonce(signature.signer),
                        signature.deadline
                    )
                )
            ),
            signature
        );
    }
    function validateLegacyCollectSignature(
        Types.EIP712Signature calldata signature,
        Types.CollectParams calldata collectParams
    ) external {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.LEGACY_COLLECT,
                        collectParams.publicationCollectedProfileId,
                        collectParams.publicationCollectedId,
                        collectParams.collectorProfileId,
                        collectParams.referrerProfileId,
                        collectParams.referrerPubId,
                        keccak256(collectParams.collectModuleData),
                        _getAndIncrementNonce(signature.signer),
                        signature.deadline
                    )
                )
            ),
            signature
        );
    }
    function validateActSignature(
        Types.EIP712Signature calldata signature,
        Types.PublicationActionParams calldata publicationActionParams
    ) external {
        _validateRecoveredAddress(
            _calculateDigest(
                keccak256(
                    abi.encode(
                        Typehash.ACT,
                        publicationActionParams.publicationActedProfileId,
                        publicationActionParams.publicationActedId,
                        publicationActionParams.actorProfileId,
                        publicationActionParams.referrerProfileIds,
                        publicationActionParams.referrerPubIds,
                        publicationActionParams.actionModuleAddress,
                        keccak256(publicationActionParams.actionModuleData),
                        _getAndIncrementNonce(signature.signer),
                        signature.deadline
                    )
                )
            ),
            signature
        );
    }
    function calculateDomainSeparator() internal view returns (bytes32) {
        if (address(this) == LENS_HUB_ADDRESS) {
            return LENS_HUB_CACHED_POLYGON_DOMAIN_SEPARATOR;
        }
        return
            keccak256(
                abi.encode(
                    Typehash.EIP712_DOMAIN,
                    keccak256(bytes(ILensERC721(address(this)).name())),
                    EIP712_DOMAIN_VERSION_HASH,
                    block.chainid,
                    address(this)
                )
            );
    }
    function _validateRecoveredAddress(bytes32 digest, Types.EIP712Signature calldata signature) private view {
        if (signature.deadline < block.timestamp) revert Errors.SignatureExpired();
        if (signature.signer.code.length != 0) {
            bytes memory concatenatedSig = abi.encodePacked(signature.r, signature.s, signature.v);
            if (IERC1271(signature.signer).isValidSignature(digest, concatenatedSig) != EIP1271_MAGIC_VALUE) {
                revert Errors.SignatureInvalid();
            }
        } else {
            address recoveredAddress = ecrecover(digest, signature.v, signature.r, signature.s);
            if (recoveredAddress == address(0) || recoveredAddress != signature.signer) {
                revert Errors.SignatureInvalid();
            }
        }
    }
    function _calculateDigest(bytes32 hashedMessage) private view returns (bytes32) {
        return keccak256(abi.encodePacked('\x19\x01', calculateDomainSeparator(), hashedMessage));
    }
    function _getAndIncrementNonce(address user) private returns (uint256) {
        unchecked {
            return StorageLib.nonces()[user]++;
        }
    }
}
interface ILensHub is ILensProfiles, ILensProtocol, ILensGovernable, ILensHubEventHooks, ILensImplGetters {}
abstract contract LensBaseERC721 is ERC165, ILensERC721 {
    using Address for address;
    using Strings for uint256;
    string private _name;
    string private _symbol;
    mapping(uint256 => Types.TokenData) private _tokenData;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(address => mapping(uint256 => uint256)) private __DEPRECATED__ownedTokens;
    mapping(uint256 => uint256) private __DEPRECATED__ownedTokensIndex;
    uint256 private _totalSupply;  
    mapping(uint256 => uint256) private __DEPRECATED__allTokensIndex;
    mapping(address => uint256) private _nonces;
    function _initialize(string calldata name_, string calldata symbol_) internal {
        _name = name_;
        _symbol = symbol_;
    }
    function tokenURI(uint256 tokenId) external view virtual returns (string memory);
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Timestamped).interfaceId ||
            interfaceId == type(IERC721Burnable).interfaceId ||
            interfaceId == type(IERC721MetaTx).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
    function nonces(address signer) public view override returns (uint256) {
        return _nonces[signer];
    }
    function getDomainSeparator() external view virtual override returns (bytes32) {
        return MetaTxLib.calculateDomainSeparator();
    }
    function balanceOf(address owner) public view virtual override returns (uint256) {
        if (owner == address(0)) {
            revert Errors.InvalidParameter();
        }
        return _balances[owner];
    }
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _tokenData[tokenId].owner;
        if (owner == address(0)) {
            revert Errors.TokenDoesNotExist();
        }
        return owner;
    }
    function mintTimestampOf(uint256 tokenId) public view virtual override returns (uint256) {
        uint96 mintTimestamp = _tokenData[tokenId].mintTimestamp;
        if (mintTimestamp == 0) {
            revert Errors.TokenDoesNotExist();
        }
        return mintTimestamp;
    }
    function tokenDataOf(uint256 tokenId) public view virtual override returns (Types.TokenData memory) {
        if (!_exists(tokenId)) {
            revert Errors.TokenDoesNotExist();
        }
        return _tokenData[tokenId];
    }
    function exists(uint256 tokenId) public view virtual override returns (bool) {
        return _exists(tokenId);
    }
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        if (to == owner) {
            revert Errors.InvalidParameter();
        }
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert Errors.NotOwnerOrApproved();
        }
        _approve(to, tokenId);
    }
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) {
            revert Errors.TokenDoesNotExist();
        }
        return _tokenApprovals[tokenId];
    }
    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (operator == msg.sender) {
            revert Errors.InvalidParameter();
        }
        _setOperatorApproval(msg.sender, operator, approved);
    }
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert Errors.NotOwnerOrApproved();
        }
        _transfer(from, to, tokenId);
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, '');
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert Errors.NotOwnerOrApproved();
        }
        _safeTransfer(from, to, tokenId, _data);
    }
    function burn(uint256 tokenId) public virtual override {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert Errors.NotOwnerOrApproved();
        }
        _burn(tokenId);
    }
    function _unsafeOwnerOf(uint256 tokenId) internal view returns (address) {
        return _tokenData[tokenId].owner;
    }
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, _data)) {
            revert Errors.NonERC721ReceiverImplementer();
        }
    }
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _tokenData[tokenId].owner != address(0);
    }
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        if (!_exists(tokenId)) {
            revert Errors.TokenDoesNotExist();
        }
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }
    function _mint(address to, uint256 tokenId) internal virtual {
        if (to == address(0) || _exists(tokenId)) {
            revert Errors.InvalidParameter();
        }
        _beforeTokenTransfer(address(0), to, tokenId);
        unchecked {
            ++_balances[to];
            ++_totalSupply;
        }
        _tokenData[tokenId].owner = to;
        _tokenData[tokenId].mintTimestamp = uint96(block.timestamp);
        emit Transfer(address(0), to, tokenId);
    }
    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);
        _beforeTokenTransfer(owner, address(0), tokenId);
        _approve(address(0), tokenId);
        unchecked {
            --_balances[owner];
            --_totalSupply;
        }
        delete _tokenData[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        if (ownerOf(tokenId) != from) {
            revert Errors.InvalidOwner();
        }
        if (to == address(0)) {
            revert Errors.InvalidParameter();
        }
        _beforeTokenTransfer(from, to, tokenId);
        _approve(address(0), tokenId);
        unchecked {
            --_balances[from];
            ++_balances[to];
        }
        _tokenData[tokenId].owner = to;
        emit Transfer(from, to, tokenId);
    }
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }
    function _setOperatorApproval(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert Errors.NonERC721ReceiverImplementer();
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}
contract FollowNFT is HubRestricted, LensBaseERC721, ERC2981CollectionRoyalties, IFollowNFT {
    using Strings for uint256;
    string constant FOLLOW_NFT_NAME_SUFFIX = '-Follower';
    string constant FOLLOW_NFT_SYMBOL_SUFFIX = '-Fl';
    uint256[5] ___DEPRECATED_SLOTS;  
    uint256 internal _followedProfileId;
    uint128 internal _lastFollowTokenId;
    uint128 internal _followerCount;
    bool private _initialized;
    mapping(uint256 => Types.FollowData) internal _followDataByFollowTokenId;
    mapping(uint256 => uint256) internal _followTokenIdByFollowerProfileId;
    mapping(uint256 => uint256) internal _followApprovalByFollowTokenId;
    uint256 internal _royaltiesInBasisPoints;
    event FollowApproval(uint256 indexed followerProfileId, uint256 indexed followTokenId);
    constructor(address hub) HubRestricted(hub) {
        _initialized = true;
    }
    function initialize(uint256 profileId) external override {
        if (_initialized) {
            revert Errors.Initialized();
        }
        _initialized = true;
        _followedProfileId = profileId;
        _setRoyalty(1000);  
    }
    function follow(
        uint256 followerProfileId,
        address transactionExecutor,
        uint256 followTokenId
    ) external override onlyHub returns (uint256) {
        if (_followTokenIdByFollowerProfileId[followerProfileId] != 0) {
            revert AlreadyFollowing();
        }
        if (followTokenId == 0) {
            return _followMintingNewToken(followerProfileId);
        }
        address followTokenOwner = _unsafeOwnerOf(followTokenId);
        if (followTokenOwner != address(0)) {
            return
                _followWithWrappedToken({
                    followerProfileId: followerProfileId,
                    transactionExecutor: transactionExecutor,
                    followTokenId: followTokenId,
                    followTokenOwner: followTokenOwner
                });
        }
        uint256 currentFollowerProfileId = _followDataByFollowTokenId[followTokenId].followerProfileId;
        if (currentFollowerProfileId != 0) {
            return
                _followWithUnwrappedTokenFromBurnedProfile({
                    followerProfileId: followerProfileId,
                    followTokenId: followTokenId,
                    currentFollowerProfileId: currentFollowerProfileId
                });
        }
        return _followByRecoveringToken({followerProfileId: followerProfileId, followTokenId: followTokenId});
    }
    function unfollow(uint256 unfollowerProfileId, address transactionExecutor) external override onlyHub {
        uint256 followTokenId = _followTokenIdByFollowerProfileId[unfollowerProfileId];
        if (followTokenId == 0) {
            revert NotFollowing();
        }
        address followTokenOwner = _unsafeOwnerOf(followTokenId);
        if (followTokenOwner == address(0)) {
            _unfollow({unfollower: unfollowerProfileId, followTokenId: followTokenId});
            _followDataByFollowTokenId[followTokenId].profileIdAllowedToRecover = unfollowerProfileId;
        } else {
            address unfollowerProfileOwner = IERC721(HUB).ownerOf(unfollowerProfileId);
            if (
                (followTokenOwner != unfollowerProfileOwner) &&
                (followTokenOwner != transactionExecutor) &&
                !isApprovedForAll(followTokenOwner, transactionExecutor) &&
                !isApprovedForAll(followTokenOwner, unfollowerProfileOwner)
            ) {
                revert DoesNotHavePermissions();
            }
            _unfollow({unfollower: unfollowerProfileId, followTokenId: followTokenId});
        }
    }
    function removeFollower(uint256 followTokenId) external override {
        address followTokenOwner = ownerOf(followTokenId);
        if (followTokenOwner == msg.sender || isApprovedForAll(followTokenOwner, msg.sender)) {
            _unfollowIfHasFollower(followTokenId);
        } else {
            revert DoesNotHavePermissions();
        }
    }
    function approveFollow(uint256 followerProfileId, uint256 followTokenId) external override {
        if (!IERC721Timestamped(HUB).exists(followerProfileId)) {
            revert Errors.TokenDoesNotExist();
        }
        address followTokenOwner = _unsafeOwnerOf(followTokenId);
        if (followTokenOwner == address(0)) {
            revert OnlyWrappedFollowTokens();
        }
        if (followTokenOwner != msg.sender && !isApprovedForAll(followTokenOwner, msg.sender)) {
            revert DoesNotHavePermissions();
        }
        _approveFollow(followerProfileId, followTokenId);
    }
    function wrap(uint256 followTokenId, address wrappedTokenReceiver) external override {
        if (wrappedTokenReceiver == address(0)) {
            revert Errors.InvalidParameter();
        }
        _wrap(followTokenId, wrappedTokenReceiver);
    }
    function wrap(uint256 followTokenId) external override {
        _wrap(followTokenId, address(0));
    }
    function _wrap(uint256 followTokenId, address wrappedTokenReceiver) internal {
        if (_isFollowTokenWrapped(followTokenId)) {
            revert AlreadyWrapped();
        }
        uint256 followerProfileId = _followDataByFollowTokenId[followTokenId].followerProfileId;
        if (followerProfileId == 0) {
            followerProfileId = _followDataByFollowTokenId[followTokenId].profileIdAllowedToRecover;
            if (followerProfileId == 0) {
                revert FollowTokenDoesNotExist();
            }
            delete _followDataByFollowTokenId[followTokenId].profileIdAllowedToRecover;
        }
        address followerProfileOwner = IERC721(HUB).ownerOf(followerProfileId);
        if (msg.sender != followerProfileOwner) {
            revert DoesNotHavePermissions();
        }
        _mint(wrappedTokenReceiver == address(0) ? followerProfileOwner : wrappedTokenReceiver, followTokenId);
    }
    function unwrap(uint256 followTokenId) external override {
        if (_followDataByFollowTokenId[followTokenId].followerProfileId == 0) {
            revert NotFollowing();
        }
        super.burn(followTokenId);
    }
    function processBlock(uint256 followerProfileId) external override onlyHub returns (bool) {
        bool hasUnfollowed;
        uint256 followTokenId = _followTokenIdByFollowerProfileId[followerProfileId];
        if (followTokenId != 0) {
            if (!_isFollowTokenWrapped(followTokenId)) {
                _mint(IERC721(HUB).ownerOf(followerProfileId), followTokenId);
            }
            _unfollow(followerProfileId, followTokenId);
            hasUnfollowed = true;
        }
        return hasUnfollowed;
    }
    function getFollowerProfileId(uint256 followTokenId) external view override returns (uint256) {
        return _followDataByFollowTokenId[followTokenId].followerProfileId;
    }
    function isFollowing(uint256 followerProfileId) external view override returns (bool) {
        return _followTokenIdByFollowerProfileId[followerProfileId] != 0;
    }
    function getFollowTokenId(uint256 followerProfileId) external view override returns (uint256) {
        return _followTokenIdByFollowerProfileId[followerProfileId];
    }
    function getOriginalFollowTimestamp(uint256 followTokenId) external view override returns (uint256) {
        return _followDataByFollowTokenId[followTokenId].originalFollowTimestamp;
    }
    function getFollowTimestamp(uint256 followTokenId) external view override returns (uint256) {
        return _followDataByFollowTokenId[followTokenId].followTimestamp;
    }
    function getProfileIdAllowedToRecover(uint256 followTokenId) external view override returns (uint256) {
        return _followDataByFollowTokenId[followTokenId].profileIdAllowedToRecover;
    }
    function getFollowData(uint256 followTokenId) external view override returns (Types.FollowData memory) {
        return _followDataByFollowTokenId[followTokenId];
    }
    function getFollowApproved(uint256 followTokenId) external view override returns (uint256) {
        return _followApprovalByFollowTokenId[followTokenId];
    }
    function getFollowerCount() external view override returns (uint256) {
        return _followerCount;
    }
    function burn(uint256 followTokenId) public override {
        _unfollowIfHasFollower(followTokenId);
        super.burn(followTokenId);
    }
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(LensBaseERC721, ERC2981CollectionRoyalties)
        returns (bool)
    {
        return
            LensBaseERC721.supportsInterface(interfaceId) || ERC2981CollectionRoyalties.supportsInterface(interfaceId);
    }
    function name() public view override returns (string memory) {
        return string(abi.encodePacked(_followedProfileId.toString(), FOLLOW_NFT_NAME_SUFFIX));
    }
    function symbol() public view override returns (string memory) {
        return string(abi.encodePacked(_followedProfileId.toString(), FOLLOW_NFT_SYMBOL_SUFFIX));
    }
    function tokenURI(uint256 followTokenId) public view override returns (string memory) {
        if (!_exists(followTokenId)) {
            revert Errors.TokenDoesNotExist();
        }
        return
            FollowTokenURILib.getTokenURI(
                followTokenId,
                _followedProfileId,
                _followDataByFollowTokenId[followTokenId].originalFollowTimestamp
            );
    }
    function _followMintingNewToken(uint256 followerProfileId) internal returns (uint256) {
        uint256 followTokenIdAssigned;
        unchecked {
            followTokenIdAssigned = ++_lastFollowTokenId;
            _followerCount++;
        }
        _baseFollow({
            followerProfileId: followerProfileId,
            followTokenId: followTokenIdAssigned,
            isOriginalFollow: true
        });
        return followTokenIdAssigned;
    }
    function _followWithWrappedToken(
        uint256 followerProfileId,
        address transactionExecutor,
        uint256 followTokenId,
        address followTokenOwner
    ) internal returns (uint256) {
        bool isFollowApproved = _followApprovalByFollowTokenId[followTokenId] == followerProfileId;
        address followerProfileOwner = IERC721(HUB).ownerOf(followerProfileId);
        if (
            !isFollowApproved &&
            followTokenOwner != followerProfileOwner &&
            followTokenOwner != transactionExecutor &&
            !isApprovedForAll(followTokenOwner, transactionExecutor) &&
            !isApprovedForAll(followTokenOwner, followerProfileOwner)
        ) {
            revert DoesNotHavePermissions();
        }
        if (isFollowApproved) {
            _approveFollow(0, followTokenId);
        }
        _replaceFollower({
            currentFollowerProfileId: _followDataByFollowTokenId[followTokenId].followerProfileId,
            newFollowerProfileId: followerProfileId,
            followTokenId: followTokenId
        });
        return followTokenId;
    }
    function _followWithUnwrappedTokenFromBurnedProfile(
        uint256 followerProfileId,
        uint256 followTokenId,
        uint256 currentFollowerProfileId
    ) internal returns (uint256) {
        if (IERC721Timestamped(HUB).exists(currentFollowerProfileId)) {
            revert DoesNotHavePermissions();
        }
        _replaceFollower({
            currentFollowerProfileId: currentFollowerProfileId,
            newFollowerProfileId: followerProfileId,
            followTokenId: followTokenId
        });
        return followTokenId;
    }
    function _followByRecoveringToken(uint256 followerProfileId, uint256 followTokenId) internal returns (uint256) {
        if (_followDataByFollowTokenId[followTokenId].profileIdAllowedToRecover != followerProfileId) {
            revert FollowTokenDoesNotExist();
        }
        unchecked {
            _followerCount++;
        }
        _baseFollow({followerProfileId: followerProfileId, followTokenId: followTokenId, isOriginalFollow: false});
        return followTokenId;
    }
    function _replaceFollower(
        uint256 currentFollowerProfileId,
        uint256 newFollowerProfileId,
        uint256 followTokenId
    ) internal {
        if (currentFollowerProfileId != 0) {
            delete _followTokenIdByFollowerProfileId[currentFollowerProfileId];
            ILensHub(HUB).emitUnfollowedEvent(currentFollowerProfileId, _followedProfileId);
        } else {
            unchecked {
                _followerCount++;
            }
        }
        _baseFollow({followerProfileId: newFollowerProfileId, followTokenId: followTokenId, isOriginalFollow: false});
    }
    function _baseFollow(
        uint256 followerProfileId,
        uint256 followTokenId,
        bool isOriginalFollow
    ) internal {
        _followTokenIdByFollowerProfileId[followerProfileId] = followTokenId;
        _followDataByFollowTokenId[followTokenId].followerProfileId = uint160(followerProfileId);
        _followDataByFollowTokenId[followTokenId].followTimestamp = uint48(block.timestamp);
        delete _followDataByFollowTokenId[followTokenId].profileIdAllowedToRecover;
        if (isOriginalFollow) {
            _followDataByFollowTokenId[followTokenId].originalFollowTimestamp = uint48(block.timestamp);
        } else {
            if (_followDataByFollowTokenId[followTokenId].originalFollowTimestamp == 0) {
                uint48 mintTimestamp = uint48(StorageLib.getTokenData(followTokenId).mintTimestamp);
                _followDataByFollowTokenId[followTokenId].originalFollowTimestamp = mintTimestamp;
            }
        }
    }
    function _unfollowIfHasFollower(uint256 followTokenId) internal {
        uint256 followerProfileId = _followDataByFollowTokenId[followTokenId].followerProfileId;
        if (followerProfileId != 0) {
            _unfollow(followerProfileId, followTokenId);
            ILensHub(HUB).emitUnfollowedEvent(followerProfileId, _followedProfileId);
        }
    }
    function _unfollow(uint256 unfollower, uint256 followTokenId) internal {
        unchecked {
            _followerCount--;
        }
        delete _followTokenIdByFollowerProfileId[unfollower];
        delete _followDataByFollowTokenId[followTokenId].followerProfileId;
        delete _followDataByFollowTokenId[followTokenId].followTimestamp;
        delete _followDataByFollowTokenId[followTokenId].profileIdAllowedToRecover;
    }
    function _approveFollow(uint256 approvedProfileId, uint256 followTokenId) internal {
        _followApprovalByFollowTokenId[followTokenId] = approvedProfileId;
        emit FollowApproval(approvedProfileId, followTokenId);
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 followTokenId
    ) internal override {
        if (from != address(0)) {
            _approveFollow(0, followTokenId);
        }
        super._beforeTokenTransfer(from, to, followTokenId);
    }
    function _getReceiver(
        uint256  
    ) internal view override returns (address) {
        return IERC721(HUB).ownerOf(_followedProfileId);
    }
    function _beforeRoyaltiesSet(
        uint256  
    ) internal view override {
        if (IERC721(HUB).ownerOf(_followedProfileId) != msg.sender) {
            revert Errors.NotProfileOwner();
        }
    }
    function _isFollowTokenWrapped(uint256 followTokenId) internal view returns (bool) {
        return _exists(followTokenId);
    }
    function _getRoyaltiesInBasisPointsSlot() internal pure override returns (uint256) {
        uint256 slot;
        assembly {
            slot := _royaltiesInBasisPoints.slot
        }
        return slot;
    }
    function tryMigrate(
        uint256 followerProfileId,
        address followerProfileOwner,
        uint256 idOfProfileFollowed,
        uint256 followTokenId
    ) external onlyHub returns (uint48) {
        if (_followDataByFollowTokenId[followTokenId].originalFollowTimestamp != 0) {
            return 0;  
        }
        if (_followedProfileId != idOfProfileFollowed) {
            revert Errors.InvalidParameter();
        }
        if (!_exists(followTokenId)) {
            return 0;  
        }
        address followTokenOwner = ownerOf(followTokenId);
        if (followerProfileOwner != followTokenOwner) {
            return 0;  
        }
        unchecked {
            ++_followerCount;
        }
        _followTokenIdByFollowerProfileId[followerProfileId] = followTokenId;
        uint48 mintTimestamp = uint48(StorageLib.getTokenData(followTokenId).mintTimestamp);
        _followDataByFollowTokenId[followTokenId].followerProfileId = uint160(followerProfileId);
        _followDataByFollowTokenId[followTokenId].originalFollowTimestamp = mintTimestamp;
        _followDataByFollowTokenId[followTokenId].followTimestamp = mintTimestamp;
        super._burn(followTokenId);
        return mintTimestamp;
    }
}