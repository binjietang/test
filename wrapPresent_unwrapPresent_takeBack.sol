// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PresentContract is Ownable {
    // 礼物资产结构
    struct Asset {
        address token;
        uint256 amount;
    }

    // 礼物目前状态结构，详细信息
    struct Present {
        address sender;
        address[] recipients;
        Asset[] assets;
        bool isUnwrapped;
        bool isTakenBack;
    }

    // presents id值对应的Present状态
    mapping(bytes32 => Present) private presents;



    ERC721 public wrappedPresentNFT;
    ERC721 public unwrappedPresentNFT;


    constructor() {
        wrappedPresentNFT = new ERC721("WrappedPresent", "WP");
        unwrappedPresentNFT = new ERC721("UnwrappedPresent", "UP");
    }

    // 打包礼物：recipients代表接收者名单，assets代表的Asset结构上文已有，calldata用于节省gas
    function wrapPresent(address[] calldata recipients, Asset[] calldata assets) external payable {
        // 生成礼物ID
        bytes32 presentId = keccak256(abi.encodePacked(msg.sender, blockhash(block.number)));

        // 处理ETH
        if (msg.value > 0) {
            // 8.8当前为空代码，看后续需要更改
        }

        // 处理ERC20和ERC721资产，从msg.sender发送到当前合约地址，代码有安全漏洞之后再说吧
        for (uint256 i = 0; i < assets.length; i++) {
            Asset memory asset = assets[i];
            if (asset.token == address(0)) continue; // 跳过ETH

            // 检查是ERC20还是ERC721
            if (IERC20(asset.token).supportsInterface(type(IERC20).interfaceId)) {
                require(IERC20(asset.token).transferFrom(msg.sender, address(this), asset.amount), "ERC20 transfer failed");
            } else if (IERC721(asset.token).supportsInterface(type(IERC721).interfaceId)) {
                require(IERC721(asset.token).transferFrom(msg.sender, address(this), asset.amount), "ERC721 transfer failed");
            }
        }

        // 存储礼物信息
        presents[presentId] = Present({
            sender: msg.sender,
            recipients: recipients,
            assets: assets,
            isUnwrapped: false,
            isTakenBack: false
        });

        // 给sender铸造Wrapped Present NFT
        wrappedPresentNFT.mint(msg.sender, presentId);
    }

    // 拆开礼物
    function unwrapPresent(bytes32 presentId) external {
        Present storage present = presents[presentId];
        require(present.sender != address(0), "Present not exist");
        require(!present.isUnwrapped, "Present already unwrapped");
        require(!present.isTakenBack, "Present already taken back");

        // 检查调用者是否是recipient之一
        bool isRecipient = false;
        for (uint256 i = 0; i < present.recipients.length; i++) {
            if (present.recipients[i] == msg.sender) {
                isRecipient = true;
                break;
            }
        }
        require(isRecipient, "Not a recipient");

        // 标记为已拆开
        present.isUnwrapped = true;

        // 转移ETH
        if (address(this).balance > 0) {
            (bool success, ) = msg.sender.call{value: address(this).balance}("");
            require(success, "ETH transfer failed");
        }

        // 转移ERC20和ERC721资产
        for (uint256 i = 0; i < present.assets.length; i++) {
            Asset memory asset = present.assets[i];
            if (asset.token == address(0)) continue; // 跳过ETH

            if (IERC20(asset.token).supportsInterface(type(IERC20).interfaceId)) {
                require(IERC20(asset.token).transfer(msg.sender, asset.amount), "ERC20 transfer failed");
            } else if (IERC721(asset.token).supportsInterface(type(IERC721).interfaceId)) {
                require(IERC721(asset.token).transferFrom(address(this), msg.sender, asset.amount), "ERC721 transfer failed");
            }
        }

        // 给调用者铸造Unwrapped Present NFT
        unwrappedPresentNFT.mint(msg.sender, presentId);
    }

    // 收回礼物
    function takeBack(bytes32 presentId) external {
        Present storage present = presents[presentId];
        require(present.sender != address(0), "Present not exist");
        require(!present.isUnwrapped, "Present already unwrapped");
        require(!present.isTakenBack, "Present already taken back");
        require(msg.sender == present.sender, "Only sender can take back");

        // 标记为已收回
        present.isTakenBack = true;

        // 转移ETH回sender
        if (address(this).balance > 0) {
            (bool success, ) = present.sender.call{value: address(this).balance}("");
            require(success, "ETH transfer failed");
        }

        // 转移ERC20和ERC721资产回sender
        for (uint256 i = 0; i < present.assets.length; i++) {
            Asset memory asset = present.assets[i];
            if (asset.token == address(0)) continue; // 跳过ETH

            if (IERC20(asset.token).supportsInterface(type(IERC20).interfaceId)) {
                require(IERC20(asset.token).transfer(present.sender, asset.amount), "ERC20 transfer failed");
            } else if (IERC721(asset.token).supportsInterface(type(IERC721).interfaceId)) {
                require(IERC721(asset.token).transferFrom(address(this), present.sender, asset.amount), "ERC721 transfer failed");
            }
        }

        // 可以在这里添加逻辑，如销毁Wrapped Present NFT
    }

    // 查看礼物信息
    function getPresentInfo(bytes32 presentId) external view returns (Present memory) {
        return presents[presentId];
    }
}