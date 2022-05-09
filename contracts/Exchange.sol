// contracts/Exchange.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./FeeManager.sol";

import "./interfaces/IERC20Metadata.sol";

contract Exchange is Pausable, FeeManager, AccessControl {
    using Address for address;
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _totalTokens;
    Counters.Counter private symbolNameIndex;
    Counters.Counter private _pairIdCounter;
    Counters.Counter private _positions;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant SUPER_ADM_ROLE = keccak256("SUPER_ADM_ROLE");

    constructor() {
        _setupRole(MANAGER_ROLE, msg.sender);
        _setupRole(SUPER_ADM_ROLE, msg.sender);
    }

    function setPaused(bool _setPaused) public onlyRole(MANAGER_ROLE) {
        return (_setPaused) ? _pause() : _unpause();
    }

    struct Offer {
        uint256 amountTokens;
        address who;
        address baseToken;
        address quoteToken;
    }

    struct OrderBook {
        uint256 higherPrice;
        uint256 lowerPrice;
        mapping(uint256 => Offer) offers;
        uint256 offers_key;
        uint256 offers_length;
    }

    struct TokenItem {
        uint256 curSellPrice;
        uint256 highestSellPrice;
        uint256 amountSellPrices;
        uint256 curBuyPrice;
        uint256 lowestBuyPrice;
        uint256 amountBuyPrices;
        address tokenContract;
        string symbolName;
        uint256 decimal;
    }

    struct ItemPair {
        uint256 id;
        address baseToken;
        string baseCurrency;
        uint8 baseScale;
        uint256 baseMinSize;
        uint256 baseMaxSize;
        address quoteToken;
        string quoteCurrency;
        uint8 quoteScale;
        uint256 quoteMinSize;
        uint256 quoteMaxSize;
        uint256 position;
        string pair;
    }

    struct OMS {
        address tokenContract;
        string pair;
        mapping(uint256 => OrderBook) buyBook;
        uint256 curBuyPrice;
        uint256 lowestBuyPrice;
        uint256 amountBuyPrices;
        mapping(uint256 => OrderBook) sellBook;
        uint256 curSellPrice;
        uint256 highestSellPrice;
        uint256 amountSellPrices;
        uint256 decimal;
    }

    mapping(string => OMS) oms;

    mapping(string => OrderBook) buyBook;
    mapping(string => OrderBook) sellBook;

    mapping(address => mapping(uint256 => uint256)) tokenBalanceForAddress;

    mapping(uint256 => TokenItem) public tokensSupport;

    mapping(address => uint256) balanceBnbForAddress;
    mapping(uint256 => ItemPair) pairs;

    function stringsEqual(string storage _a, string memory _b)
        internal
        pure
        returns (bool)
    {
        bytes storage a = bytes(_a);
        bytes memory b = bytes(_b);

        if (keccak256(a) != keccak256(b)) {
            return false;
        }
        return true;
    }

    function getSymbolIndexOrThrow(string memory symbolName)
        internal
        view
        returns (uint256)
    {
        uint256 index = getSymbolIndex(symbolName);
        require(index > 0);
        return index;
    }

    function hasToken(string memory symbolName) public view returns (bool) {
        uint256 index = getSymbolIndex(symbolName);
        if (index == 0) {
            return false;
        }
        return true;
    }

    function getSymbolIndex(string memory symbolName)
        internal
        view
        returns (uint256)
    {
        for (uint256 i = 1; i <= symbolNameIndex.current(); i++) {
            if (stringsEqual(tokensSupport[i].symbolName, symbolName)) {
                return i;
            }
        }
        return 0;
    }

    function getPairIndex(string memory pair) internal view returns (uint256) {
        for (uint256 i = 1; i <= _pairIdCounter.current(); i++) {
            if (stringsEqual(pairs[i].pair, pair)) {
                return i;
            }
        }
        return 0;
    }

    function depositBnb() public payable {
        require(
            balanceBnbForAddress[msg.sender] + msg.value >=
                balanceBnbForAddress[msg.sender]
        );
        balanceBnbForAddress[msg.sender] += msg.value;
    }

    function withdrawBnb(uint256 amountInWei) public {
        require(balanceBnbForAddress[msg.sender] - amountInWei >= 0);
        require(
            balanceBnbForAddress[msg.sender] - amountInWei <=
                balanceBnbForAddress[msg.sender]
        );

        balanceBnbForAddress[msg.sender] -= amountInWei;

        payable(msg.sender).transfer(amountInWei);
    }

    function getEthBalanceInWei() public view returns (uint256) {
        return balanceBnbForAddress[msg.sender];
    }

    // function depositToken(string memory symbolName, uint256 amountTokens)
    //     public
    // {
    //     uint256 symbolNameIndexKey = getSymbolIndexOrThrow(symbolName);
    //     require(tokens[symbolNameIndexKey].tokenContract != address(0));

    //     IERC20 token = IERC20(tokens[symbolNameIndexKey].tokenContract);

    //     require(
    //         token.transferFrom(msg.sender, address(this), amountTokens) == true
    //     );
    //     require(
    //         tokenBalanceForAddress[msg.sender][symbolNameIndexKey] +
    //             amountTokens >=
    //             tokenBalanceForAddress[msg.sender][symbolNameIndexKey]
    //     );
    //     tokenBalanceForAddress[msg.sender][symbolNameIndexKey] += amountTokens;
    // }

    // function withdrawToken(string memory symbolName, uint256 amountTokens)
    //     public
    // {
    //     uint256 symbolNameIndexKey = getSymbolIndexOrThrow(symbolName);
    //     require(tokens[symbolNameIndexKey].tokenContract != address(0));

    //     IERC20 token = IERC20(tokens[symbolNameIndexKey].tokenContract);
    //     require(
    //         tokenBalanceForAddress[msg.sender][symbolNameIndexKey] -
    //             amountTokens >=
    //             0
    //     );
    //     require(
    //         tokenBalanceForAddress[msg.sender][symbolNameIndexKey] -
    //             amountTokens <=
    //             tokenBalanceForAddress[msg.sender][symbolNameIndexKey]
    //     );
    //     tokenBalanceForAddress[msg.sender][symbolNameIndexKey] -= amountTokens;
    //     require(token.transfer(msg.sender, amountTokens) == true);
    // }

    function getBalance(string memory symbolName)
        public
        view
        returns (uint256)
    {
        uint256 symbolNameIndexKey = getSymbolIndexOrThrow(symbolName);
        return tokenBalanceForAddress[msg.sender][symbolNameIndexKey];
    }

    function getSellOrderBook(string memory pair)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint256 pairIndex = getPairIndex(pair);
        require(pairIndex > 0, "invalid pair");
        uint256[] memory arrPricesSell = new uint256[](
            oms[pair].amountSellPrices
        );
        uint256[] memory arrVolumesSell = new uint256[](
            oms[pair].amountSellPrices
        );
        uint256 sellWhilePrice = oms[pair].curSellPrice;
        uint256 sellCounter = 0;
        if (oms[pair].curSellPrice > 0) {
            while (sellWhilePrice <= oms[pair].highestSellPrice) {
                arrPricesSell[sellCounter] = sellWhilePrice;
                uint256 sellVolumeAtPrice = 0;
                uint256 sellOffersKey = 0;
                sellOffersKey = oms[pair].sellBook[sellWhilePrice].offers_key;
                while (
                    sellOffersKey <=
                    oms[pair].sellBook[sellWhilePrice].offers_length
                ) {
                    sellVolumeAtPrice += oms[pair]
                        .sellBook[sellWhilePrice]
                        .offers[sellOffersKey]
                        .amountTokens;
                    sellOffersKey++;
                }
                arrVolumesSell[sellCounter] = sellVolumeAtPrice;
                if (oms[pair].sellBook[sellWhilePrice].higherPrice == 0) {
                    break;
                } else {
                    sellWhilePrice = oms[pair]
                        .sellBook[sellWhilePrice]
                        .higherPrice;
                }
                sellCounter++;
            }
        }
        return (arrPricesSell, arrVolumesSell);
    }

    function getBuyOrderBook(string memory pair)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint256 pairIndex = getPairIndex(pair);
        require(pairIndex > 0, "invalid pair");
        uint256[] memory arrPricesBuy = new uint256[](
            oms[pair].amountBuyPrices
        );
        uint256[] memory arrVolumesBuy = new uint256[](
            oms[pair].amountBuyPrices
        );

        uint256 whilePrice = oms[pair].lowestBuyPrice;
        uint256 counter = 0;
        if (oms[pair].curBuyPrice > 0) {
            while (whilePrice <= oms[pair].curBuyPrice) {
                arrPricesBuy[counter] = whilePrice;
                uint256 buyVolumeAtPrice = 0;
                uint256 buyOffersKey = 0;
                buyOffersKey = oms[pair].buyBook[whilePrice].offers_key;
                while (
                    buyOffersKey <= oms[pair].buyBook[whilePrice].offers_length
                ) {
                    buyVolumeAtPrice += oms[pair]
                        .buyBook[whilePrice]
                        .offers[buyOffersKey]
                        .amountTokens;
                    buyOffersKey++;
                }
                arrVolumesBuy[counter] = buyVolumeAtPrice;

                if (whilePrice == oms[pair].buyBook[whilePrice].higherPrice) {
                    break;
                } else {
                    whilePrice = oms[pair].buyBook[whilePrice].higherPrice;
                }
                counter++;
            }
        }
        return (arrPricesBuy, arrVolumesBuy);
    }

    function buyToken(
        string memory pair,
        uint256 priceInWei,
        uint256 amount,
        address baseToken,
        address quoteToken
    ) public {
        uint256 pairIndex = getPairIndex(pair);
          require(pairIndex > 0, "invalid pair");
        uint256 totalAmountOfEtherNecessary = 0;
        uint256 amountOfTokensNecessary = amount;

        if (
            oms[pair].amountSellPrices == 0 ||
            oms[pair].curSellPrice > priceInWei
        ) {
            createBuyLimitOrderForTokensUnableToMatchWithSellOrderForBuyer(
                pair,
                priceInWei,
                amountOfTokensNecessary,
                totalAmountOfEtherNecessary,
                baseToken,
                quoteToken
            );
        } else {
            uint256 totalAmountOfEtherAvailable = 0;
            uint256 whilePrice = oms[pair].curSellPrice;
            uint256 offers_key;
            while (whilePrice <= priceInWei && amountOfTokensNecessary > 0) {
                offers_key = oms[pair].sellBook[whilePrice].offers_key;
                while (
                    offers_key <=
                    oms[pair].sellBook[whilePrice].offers_length &&
                    amountOfTokensNecessary > 0
                ) {
                    uint256 volumeAtPriceFromAddress = oms[pair]
                        .sellBook[whilePrice]
                        .offers[offers_key]
                        .amountTokens;

                    if (volumeAtPriceFromAddress <= amountOfTokensNecessary) {
                        totalAmountOfEtherAvailable =
                            volumeAtPriceFromAddress *
                            whilePrice;
                        require(
                            balanceBnbForAddress[msg.sender] >=
                                totalAmountOfEtherAvailable
                        );
                        require(
                            balanceBnbForAddress[msg.sender] -
                                totalAmountOfEtherAvailable <=
                                balanceBnbForAddress[msg.sender]
                        );
                        balanceBnbForAddress[
                            msg.sender
                        ] -= totalAmountOfEtherAvailable;

                        require(
                            balanceBnbForAddress[msg.sender] >=
                                totalAmountOfEtherAvailable
                        );
                        require(uint256(1) > uint256(0));
                        require(
                            tokenBalanceForAddress[msg.sender][pairIndex] +
                                volumeAtPriceFromAddress >=
                                tokenBalanceForAddress[msg.sender][pairIndex]
                        );
                         // check balance ERC20 - todo

                        // require(
                        //     balanceBnbForAddress[
                        //         oms[pair]
                        //             .sellBook[whilePrice]
                        //             .offers[offers_key]
                        //             .who
                        //     ] +
                        //         totalAmountOfEtherAvailable >=
                        //         balanceBnbForAddress[
                        //             oms[pair]
                        //                 .sellBook[whilePrice]
                        //                 .offers[offers_key]
                        //                 .who
                        //         ]
                        // );

                        tokenBalanceForAddress[msg.sender][
                            pairIndex
                        ] += volumeAtPriceFromAddress;

                        oms[pair]
                            .sellBook[whilePrice]
                            .offers[offers_key]
                            .amountTokens = 0;

                        balanceBnbForAddress[
                            oms[pair]
                                .sellBook[whilePrice]
                                .offers[offers_key]
                                .who
                        ] += totalAmountOfEtherAvailable;
                        oms[pair].sellBook[whilePrice].offers_key++;

                        amountOfTokensNecessary -= volumeAtPriceFromAddress;
                    } else {
                        require(
                            oms[pair]
                                .sellBook[whilePrice]
                                .offers[offers_key]
                                .amountTokens > amountOfTokensNecessary
                        );

                        totalAmountOfEtherNecessary =
                            amountOfTokensNecessary *
                            whilePrice;

                        // Overflow Check
                        require(
                            balanceBnbForAddress[msg.sender] -
                                totalAmountOfEtherNecessary <=
                                balanceBnbForAddress[msg.sender]
                        );

                        balanceBnbForAddress[
                            msg.sender
                    
                        ] -= totalAmountOfEtherNecessary;

                         // check balance ERC20 - todo

                        // Overflow Check
                        // require(
                        //     balanceBnbForAddress[
                        //         oms[pair]
                        //             .sellBook[whilePrice]
                        //             .offers[offers_key]
                        //             .who
                        //     ] +
                        //         totalAmountOfEtherNecessary >=
                        //         balanceBnbForAddress[
                        //             oms[pair]
                        //                 .sellBook[whilePrice]
                        //                 .offers[offers_key]
                        //                 .who
                        //         ]
                        // );

                        oms[pair]
                            .sellBook[whilePrice]
                            .offers[offers_key]
                            .amountTokens -= amountOfTokensNecessary;
                        balanceBnbForAddress[
                            oms[pair]
                                .sellBook[whilePrice]
                                .offers[offers_key]
                                .who
                        ] += totalAmountOfEtherNecessary;
                        tokenBalanceForAddress[msg.sender][
                            pairIndex
                        ] += amountOfTokensNecessary;
                        amountOfTokensNecessary = 0;
                    }

                    if (
                        offers_key ==
                        oms[pair].sellBook[whilePrice].offers_length &&
                        oms[pair]
                            .sellBook[whilePrice]
                            .offers[offers_key]
                            .amountTokens ==
                        0
                    ) {
                        oms[pair].amountSellPrices--;
                        if (
                            whilePrice ==
                            oms[pair].sellBook[whilePrice].higherPrice ||
                            oms[pair].sellBook[whilePrice].higherPrice == 0
                        ) {
                            oms[pair].curSellPrice = 0;
                        } else {
                            oms[pair].curSellPrice = oms[pair]
                                .sellBook[whilePrice]
                                .higherPrice;
                            oms[pair]
                                .sellBook[
                                    oms[pair]
                                        .sellBook[whilePrice]
                                        .higherPrice
                                ]
                                .lowerPrice = 0;
                        }
                    }
                    offers_key++;
                }
                whilePrice = oms[pair].curSellPrice;
            }

            if (amountOfTokensNecessary > 0) {
                createBuyLimitOrderForTokensUnableToMatchWithSellOrderForBuyer(
                    pair,
                    priceInWei,
                    amountOfTokensNecessary,
                    totalAmountOfEtherNecessary,
                    baseToken,
                    quoteToken
                );
            }
        }
    }

    function createBuyLimitOrderForTokensUnableToMatchWithSellOrderForBuyer(
        string memory pair,
        uint256 priceInWei,
        uint256 amountOfTokensNecessary,
        uint256 totalAmountOfEtherNecessary,
        address baseToken,
        address quoteToken
    ) internal {
        totalAmountOfEtherNecessary = amountOfTokensNecessary * priceInWei;
        

        require(totalAmountOfEtherNecessary >= amountOfTokensNecessary);
        require(totalAmountOfEtherNecessary >= priceInWei);
        require(
            balanceBnbForAddress[msg.sender] >= totalAmountOfEtherNecessary
        );
        require(
            balanceBnbForAddress[msg.sender] - totalAmountOfEtherNecessary >= 0
        );
        require(
            balanceBnbForAddress[msg.sender] - totalAmountOfEtherNecessary <=
                balanceBnbForAddress[msg.sender]
        );

        balanceBnbForAddress[msg.sender] -= totalAmountOfEtherNecessary;
        addBuyOffer(
            pair,
            priceInWei,
            amountOfTokensNecessary,
            msg.sender,
            baseToken,
            quoteToken
        );
    }

    function addBuyOffer(
        string memory pair,
        uint256 priceInWei,
        uint256 amount,
        address who,
        address baseToken,
        address quoteToken
    ) internal {
        oms[pair].buyBook[priceInWei].offers_length++;

        oms[pair].buyBook[priceInWei].offers[
            oms[pair].buyBook[priceInWei].offers_length
        ] = Offer(amount, who, baseToken, quoteToken);

        if (oms[pair].buyBook[priceInWei].offers_length == 1) {
            oms[pair].buyBook[priceInWei].offers_key = 1;
            oms[pair].amountBuyPrices++;
            uint256 curBuyPrice = oms[pair].curBuyPrice;
            uint256 lowestBuyPrice = oms[pair].lowestBuyPrice;
            if (lowestBuyPrice == 0 || lowestBuyPrice > priceInWei) {
                if (curBuyPrice == 0) {
                    oms[pair].curBuyPrice = priceInWei;

                    oms[pair].buyBook[priceInWei].higherPrice = priceInWei;

                    oms[pair].buyBook[priceInWei].lowerPrice = 0;
                } else {
                    oms[pair]
                        .buyBook[lowestBuyPrice]
                        .lowerPrice = priceInWei;
                    oms[pair]
                        .buyBook[priceInWei]
                        .higherPrice = lowestBuyPrice;
                    oms[pair].buyBook[priceInWei].lowerPrice = 0;
                }
                oms[pair].lowestBuyPrice = priceInWei;
            } else if (curBuyPrice < priceInWei) {
                oms[pair].buyBook[curBuyPrice].higherPrice = priceInWei;
                oms[pair].buyBook[priceInWei].higherPrice = priceInWei;
                oms[pair].buyBook[priceInWei].lowerPrice = curBuyPrice;
                oms[pair].curBuyPrice = priceInWei;
            } else {
                uint256 buyPrice = oms[pair].curBuyPrice;
                bool weFoundLocation = false;
                while (buyPrice > 0 && !weFoundLocation) {
                    if (
                        buyPrice < priceInWei &&
                        oms[pair].buyBook[buyPrice].higherPrice >
                        priceInWei
                    ) {
                        oms[pair]
                            .buyBook[priceInWei]
                            .lowerPrice = buyPrice;
                        oms[pair].buyBook[priceInWei].higherPrice = oms[
                            pair
                        ].buyBook[buyPrice].higherPrice;

                        oms[pair]
                            .buyBook[
                                oms[pair].buyBook[buyPrice].higherPrice
                            ]
                            .lowerPrice = priceInWei;

                        oms[pair]
                            .buyBook[buyPrice]
                            .higherPrice = priceInWei;

                        weFoundLocation = true;
                    }
                    buyPrice = oms[pair].buyBook[buyPrice].lowerPrice;
                }
            }
        }
    }

    function addSellOffer(
        string memory pair,
        uint256 priceInWei,
        uint256 amount,
        address who,
        address baseToken,
        address quoteToken
    ) internal {
        oms[pair].sellBook[priceInWei].offers_length++;

        oms[pair].sellBook[priceInWei].offers[
            oms[pair].sellBook[priceInWei].offers_length
        ] = Offer(amount, who, baseToken, quoteToken);

        if (oms[pair].sellBook[priceInWei].offers_length == 1) {
            oms[pair].sellBook[priceInWei].offers_key = 1;
            oms[pair].amountSellPrices++;

            uint256 curSellPrice = oms[pair].curSellPrice;
            uint256 highestSellPrice = oms[pair].highestSellPrice;

            if (highestSellPrice == 0 || highestSellPrice < priceInWei) {
                if (curSellPrice == 0) {
                    oms[pair].curSellPrice = priceInWei;
                    oms[pair].sellBook[priceInWei].higherPrice = 0;
                    oms[pair].sellBook[priceInWei].lowerPrice = 0;
                } else {
                    oms[pair]
                        .sellBook[highestSellPrice]
                        .higherPrice = priceInWei;
                    oms[pair]
                        .sellBook[priceInWei]
                        .lowerPrice = highestSellPrice;
                    oms[pair].sellBook[priceInWei].higherPrice = 0;
                }
                oms[pair].highestSellPrice = priceInWei;
            } else if (curSellPrice > priceInWei) {
                oms[pair].sellBook[curSellPrice].lowerPrice = priceInWei;
                oms[pair].sellBook[priceInWei].higherPrice = curSellPrice;
                oms[pair].sellBook[priceInWei].lowerPrice = 0;
                oms[pair].curSellPrice = priceInWei;
            } else {
                uint256 sellPrice = oms[pair].curSellPrice;
                bool weFoundLocation = false;

                while (sellPrice > 0 && !weFoundLocation) {
                    if (
                        sellPrice < priceInWei &&
                        oms[pair].sellBook[sellPrice].higherPrice >
                        priceInWei
                    ) {
                        oms[pair]
                            .sellBook[priceInWei]
                            .lowerPrice = sellPrice;
                        oms[pair].sellBook[priceInWei].higherPrice = oms[
                            pair
                        ].sellBook[sellPrice].higherPrice;

                        oms[pair]
                            .sellBook[
                                oms[pair].sellBook[sellPrice].higherPrice
                            ]
                            .lowerPrice = priceInWei;

                        oms[pair]
                            .sellBook[sellPrice]
                            .higherPrice = priceInWei;

                        weFoundLocation = true;
                    }

                    sellPrice = oms[pair].sellBook[sellPrice].higherPrice;
                }
            }
        }
    }

    function cancelOrder(
        string memory pair,
        bool isSellOrder,
        uint256 priceInWei,
        uint256 offerKey
    ) public {
        uint256 pairIndex = getPairIndex(pair);

        if (isSellOrder) {
            require(
                oms[pair].sellBook[priceInWei].offers[offerKey].who ==
                    msg.sender
            );

            uint256 tokensAmount = oms[pair]
                .sellBook[priceInWei]
                .offers[offerKey]
                .amountTokens;

            require(
                tokenBalanceForAddress[msg.sender][pairIndex] + tokensAmount >=
                    tokenBalanceForAddress[msg.sender][pairIndex]
            );

            tokenBalanceForAddress[msg.sender][pairIndex] += tokensAmount;
            oms[pair]
                .sellBook[priceInWei]
                .offers[offerKey]
                .amountTokens = 0;
        } else {
            require(
                oms[pair].buyBook[priceInWei].offers[offerKey].who ==
                    msg.sender
            );
            uint256 etherToRefund = oms[pair]
                .buyBook[priceInWei]
                .offers[offerKey]
                .amountTokens * priceInWei;

            require(
                balanceBnbForAddress[msg.sender] + etherToRefund >=
                    balanceBnbForAddress[msg.sender]
            );

            balanceBnbForAddress[msg.sender] += etherToRefund;
            oms[pair]
                .buyBook[priceInWei]
                .offers[offerKey]
                .amountTokens = 0;
        }
    }

    function sellToken(
        string memory pair,
        uint256 priceInWei,
        uint256 amount,
        address baseToken,
        address quoteToken
    ) public payable {
        uint256 pairIndex = getPairIndex(pair);
        uint256 totalAmountOfEtherNecessary = 0;
        uint256 totalAmountOfEtherAvailable = 0;

        uint256 amountOfTokensNecessary = amount;

        if (
            oms[pair].amountBuyPrices == 0 ||
            oms[pair].curBuyPrice < priceInWei
        ) {
            createSellLimitOrderForTokensUnableToMatchWithBuyOrderForSeller(
                pair,
                pairIndex,
                priceInWei,
                amountOfTokensNecessary,
                totalAmountOfEtherNecessary,
                baseToken,
                quoteToken
            );
        } else {
            uint256 whilePrice = oms[pair].curBuyPrice;
            uint256 offers_key;

            while (whilePrice >= priceInWei && amountOfTokensNecessary > 0) {
                offers_key = oms[pair].buyBook[whilePrice].offers_key;

                while (
                    offers_key <=
                    oms[pair].buyBook[whilePrice].offers_length &&
                    amountOfTokensNecessary > 0
                ) {
                    uint256 volumeAtPriceFromAddress = oms[pair]
                        .buyBook[whilePrice]
                        .offers[offers_key]
                        .amountTokens;

                    if (volumeAtPriceFromAddress <= amountOfTokensNecessary) {
                        totalAmountOfEtherAvailable =
                            volumeAtPriceFromAddress *
                            whilePrice;

                        require(
                            tokenBalanceForAddress[msg.sender][pairIndex] >=
                                volumeAtPriceFromAddress
                        );

                        tokenBalanceForAddress[msg.sender][
                            pairIndex
                        ] -= volumeAtPriceFromAddress;

                        require(
                            tokenBalanceForAddress[msg.sender][pairIndex] -
                                volumeAtPriceFromAddress >=
                                0
                        );

                        // check balance ERC20 - todo

                        // require(
                        //     tokenBalanceForAddress[
                        //         oms[pair]
                        //             .buyBook[whilePrice]
                        //             .offers[offers_key]
                        //             .who
                        //     ][pairIndex] +
                        //         volumeAtPriceFromAddress >=
                        //         tokenBalanceForAddress[
                        //             oms[pair]
                        //                 .buyBook[whilePrice]
                        //                 .offers[offers_key]
                        //                 .who
                        //         ][pairIndex]
                        // );

                        require(
                            balanceBnbForAddress[msg.sender] +
                                totalAmountOfEtherAvailable >=
                                balanceBnbForAddress[msg.sender]
                        );

                        tokenBalanceForAddress[
                            oms[pair]
                                .buyBook[whilePrice]
                                .offers[offers_key]
                                .who
                        ][pairIndex] += volumeAtPriceFromAddress;

                        oms[pair]
                            .buyBook[whilePrice]
                            .offers[offers_key]
                            .amountTokens = 0;

                        balanceBnbForAddress[
                            msg.sender
                        ] += totalAmountOfEtherAvailable;

                        oms[pair].buyBook[whilePrice].offers_key++;

                        amountOfTokensNecessary -= volumeAtPriceFromAddress;
                    } else {
                        require(
                            volumeAtPriceFromAddress - amountOfTokensNecessary >
                                0
                        );

                        totalAmountOfEtherNecessary =
                            amountOfTokensNecessary *
                            whilePrice;

                        require(
                            tokenBalanceForAddress[msg.sender][pairIndex] >=
                                amountOfTokensNecessary
                        );

                        tokenBalanceForAddress[msg.sender][
                            pairIndex
                        ] -= amountOfTokensNecessary;

                        require(
                            tokenBalanceForAddress[msg.sender][pairIndex] >=
                                amountOfTokensNecessary
                        );
                        require(
                            balanceBnbForAddress[msg.sender] +
                                totalAmountOfEtherNecessary >=
                                balanceBnbForAddress[msg.sender]
                        );

                         // check balance ERC20 - todo
                        // require(
                        //     tokenBalanceForAddress[
                        //         oms[pair]
                        //             .buyBook[whilePrice]
                        //             .offers[offers_key]
                        //             .who
                        //     ][pairIndex] +
                        //         amountOfTokensNecessary >=
                        //         tokenBalanceForAddress[
                        //             oms[pair]
                        //                 .buyBook[whilePrice]
                        //                 .offers[offers_key]
                        //                 .who
                        //         ][pairIndex]
                        // );

                        oms[pair]
                            .buyBook[whilePrice]
                            .offers[offers_key]
                            .amountTokens -= amountOfTokensNecessary;

                        balanceBnbForAddress[
                            msg.sender
                        ] += totalAmountOfEtherNecessary;

                        tokenBalanceForAddress[
                            oms[pair]
                                .buyBook[whilePrice]
                                .offers[offers_key]
                                .who
                        ][pairIndex] += amountOfTokensNecessary;

                        amountOfTokensNecessary = 0;
                    }

                    if (
                        offers_key ==
                        oms[pair].buyBook[whilePrice].offers_length &&
                        oms[pair]
                            .buyBook[whilePrice]
                            .offers[offers_key]
                            .amountTokens ==
                        0
                    ) {
                        oms[pair].amountBuyPrices--;
                        if (
                            whilePrice ==
                            oms[pair].buyBook[whilePrice].lowerPrice ||
                            oms[pair].buyBook[whilePrice].lowerPrice == 0
                        ) {
                            oms[pair].curBuyPrice = 0;
                        } else {
                            oms[pair].curBuyPrice = oms[pair]
                                .buyBook[whilePrice]
                                .lowerPrice;

                            oms[pair]
                                .buyBook[
                                    oms[pair]
                                        .buyBook[whilePrice]
                                        .lowerPrice
                                ]
                                .higherPrice = oms[pair].curBuyPrice;
                        }
                    }
                    offers_key++;
                }

                whilePrice = oms[pair].curBuyPrice;
            }

            if (amountOfTokensNecessary > 0) {
                createSellLimitOrderForTokensUnableToMatchWithBuyOrderForSeller(
                    pair,
                    pairIndex,
                    priceInWei,
                    amountOfTokensNecessary,
                    totalAmountOfEtherNecessary,
                    baseToken,
                    quoteToken
                );
            }
        }
    }

    function createSellLimitOrderForTokensUnableToMatchWithBuyOrderForSeller(
        string memory pair,
        uint256 tokenNameIndex,
        uint256 priceInWei,
        uint256 amountOfTokensNecessary,
        uint256 totalAmountOfEtherNecessary,
        address baseToken,
        address quoteToken
    ) internal {
        totalAmountOfEtherNecessary = amountOfTokensNecessary * priceInWei;

        require(totalAmountOfEtherNecessary >= amountOfTokensNecessary);
        require(totalAmountOfEtherNecessary >= priceInWei);
        require(
            tokenBalanceForAddress[msg.sender][tokenNameIndex] >=
                amountOfTokensNecessary
        );
        require(
            tokenBalanceForAddress[msg.sender][tokenNameIndex] -
                amountOfTokensNecessary >=
                0
        );
        require(
            balanceBnbForAddress[msg.sender] + totalAmountOfEtherNecessary >=
                balanceBnbForAddress[msg.sender]
        );

        tokenBalanceForAddress[msg.sender][
            tokenNameIndex
        ] -= amountOfTokensNecessary;

        addSellOffer(
            pair,
            priceInWei,
            amountOfTokensNecessary,
            msg.sender,
            baseToken,
            quoteToken
        );
    }

    function addToken(address tokenAddress) public onlyRole(MANAGER_ROLE) {
        IERC20Metadata newToken = IERC20Metadata(tokenAddress);
        require(!hasToken(newToken.symbol()));
        symbolNameIndex.increment();
        tokensSupport[symbolNameIndex.current()].symbolName = newToken.symbol();
        tokensSupport[symbolNameIndex.current()].decimal = newToken.decimals();
        tokensSupport[symbolNameIndex.current()].tokenContract = tokenAddress;
    }

    function removeToken(string memory symbolName)
        public
        onlyRole(MANAGER_ROLE)
    {
        uint256 index = getSymbolIndex(symbolName);
        if (index == 0) {
            return;
        }
        delete tokensSupport[index];
    }

    function listTokens() public view returns (TokenItem[] memory _tokens) {
        uint256 totalItemCount = symbolNameIndex.current();
        uint256 currentIndex = 0;
        uint256 currentId = 1;
        _tokens = new TokenItem[](totalItemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            _tokens[currentIndex] = tokensSupport[currentId];
            currentIndex += 1;
            currentId += 1;
        }
    }

    function listPairs() public view returns (ItemPair[] memory _pair) {
        uint256 totalItemCount = _pairIdCounter.current();
        uint256 currentIndex = 0;
        _pair = new ItemPair[](totalItemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            _pair[currentIndex] = pairs[currentIndex];
            currentIndex += 1;
        }
    }

    function addPair(address baseToken, address quoteToken)
        public
        onlyRole(MANAGER_ROLE)
    {
        IERC20Metadata baseTokenRef = IERC20Metadata(baseToken);
        require(hasToken(baseTokenRef.symbol()), "invalid asset");
        IERC20Metadata quoteTokenRef = IERC20Metadata(quoteToken);
        require(hasToken(quoteTokenRef.symbol()), "invalid asset");

        string memory pair = appendString(
            baseTokenRef.symbol(),
            "-",
            quoteTokenRef.symbol()
        );
        _pairIdCounter.increment();
        _positions.increment();

        pairs[_pairIdCounter.current()] = ItemPair({
            id: _pairIdCounter.current(),
            baseToken: baseToken,
            baseCurrency: baseTokenRef.symbol(),
            baseScale: baseTokenRef.decimals(),
            baseMinSize: 0,
            baseMaxSize: 1000000,
            quoteToken: quoteToken,
            quoteCurrency: quoteTokenRef.symbol(),
            quoteScale: quoteTokenRef.decimals(),
            quoteMinSize: 0,
            quoteMaxSize: 1000000,
            position: _positions.current(),
            pair: pair
        });
    }

    function removePair(address baseToken, address quoteToken)
        public
        onlyRole(MANAGER_ROLE)
    {
        IERC20Metadata baseTokenRef = IERC20Metadata(baseToken);
        require(hasToken(baseTokenRef.symbol()), "invalid asset");
        IERC20Metadata quoteTokenRef = IERC20Metadata(quoteToken);
        require(hasToken(quoteTokenRef.symbol()), "invalid asset");

        string memory pair = appendString(
            baseTokenRef.symbol(),
            "-",
            quoteTokenRef.symbol()
        );
        uint256 index = getPairIndex(pair);
        if (index == 0) {
            return;
        }
        _pairIdCounter.decrement();
        delete pairs[index];
    }

    function appendString(
        string memory _a,
        string memory _b,
        string memory _c
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(_a, _b, _c));
    }
}
