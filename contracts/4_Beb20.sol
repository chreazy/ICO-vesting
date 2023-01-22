// SPDX-License-Identifier: GPL-3.0
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity >=0.7.0 <0.9.0;


contract Zeny is ERC20, Ownable {

    enum ICOStatus {
        Preparation,
        Whitelist,
        SeedRound,
        PrivateSale,
        PublicSale,
        End
    }

    ICOStatus public status;

    IERC20 tokenUSDT;

    struct VestingInfo {
        string[] stage;
        uint minted;
        uint locked;
        uint[] nextUnlock;
    }

    mapping(address => VestingInfo) vesting;
    mapping(address => uint) whitelistLimit;

    uint constant WHITELIST_RATE = 1; //  0.1 USDT
    uint constant SEEDROUND_RATE = 2; // 0.2 USDT
    uint constant PRIVATESALE_RATE = 4; // 0.4 USDT
    uint constant PUBLICSALE_RATE = 10; // 1 USDT

    uint constant vestingTime = 1 days * 30;

    uint constant WHITELIST_VESTING = 12; // month
    uint constant SEEDROUND_VESTING = 18; // month
    uint constant PRIVATE_VESTING = 24; // month

    mapping(address => uint) whitelisters;
    mapping(address => bool) seeds;
    mapping(address => bool) privateSalers;

    uint constant public maxSupply = 100000000;
    uint currentSupply = 0;

    uint ownerUnlock;
    uint constant public ownerShare = 10000000;
    uint public ownerMinted;
    uint public ownerLock = 1 days * 365 * 3; 

    uint developerUnlock;
    uint constant public developerShare = 4000000;
    uint public developersMinted;
    uint public developerLock = 10; 

    uint constant marketingShare = 3000000;
    uint public marketingMinted;

    uint public airdropShare = 1000000;

    uint public whitelistShare = 1000000;
    uint MAX_WHITELISTERS = 1000;
    uint totalWhitelisters;

    uint public seedRoundShare = 2000000;
    uint seedRoundMinted;

    uint public privateSaleShare = 2000000;
    uint privateRoundMinted;

    uint public publicShare = 45000000;

    uint farmingFunds = 10000000;
    uint farmingMinted;

    uint safeFunds = 9000000;
    uint safeMinted;

    uint legalizationFunds = 10000000;
    uint legalizationMinted;


    constructor(address _token) ERC20("Zeny", "ZN"){
        tokenUSDT = IERC20(_token);
        ownerUnlock = block.timestamp + ownerLock;
        developerUnlock = block.timestamp + developerLock;

    }

    function mint(address to, uint amount) internal onlyOwner {
        require(maxSupply >= currentSupply + amount, "supply error");
        _mint(to, amount);
        currentSupply += amount;
    }

    function getICOStatus() external view returns(ICOStatus) {
        return status;
    }

    function getVestingInfo(address _addr) external view returns(VestingInfo memory){
        return vesting[_addr];
    }

    function changeICOStatus(ICOStatus _newStatus) external onlyOwner {

        if(whitelistShare != 0 && _newStatus == ICOStatus.SeedRound){             
            seedRoundShare += whitelistShare;
            whitelistShare = 0;              
        }

        if(seedRoundShare != 0 && _newStatus == ICOStatus.PrivateSale){             
            privateSaleShare += seedRoundShare;
            seedRoundShare = 0;              
        }

        if(privateSaleShare != 0 && _newStatus == ICOStatus.PublicSale){             
            publicShare += privateSaleShare;
            privateSaleShare = 0;         
        }

        status = _newStatus;
    }

    function ownerMint(uint amount) public onlyOwner {
        require(block.timestamp >= ownerUnlock, "too early");
        require(ownerShare >= ownerMinted + amount, "a lot of funds");
        mint(msg.sender, amount);
        ownerMinted += amount;
    }

    function payDevelopers(address[] calldata _devs, uint amount) external onlyOwner {
        require(block.timestamp >= developerUnlock, "too early");
        require(developerShare >= developersMinted + amount * _devs.length, "a lot of funds");
        for (uint i=0; i<_devs.length; i++){
            require(_devs[i] != address(0), "zero address");
            mint(_devs[i], amount);
        }
        developersMinted += amount * _devs.length;
        developerUnlock = block.timestamp + developerLock;
    }

    function marketingFunds(address company, uint amount) external onlyOwner {
        require(company != address(0), "zero address");
        require(marketingShare >= marketingMinted + amount, "a lot of funds");
        mint(company, amount);
        marketingMinted += amount;
    }

    function farming(uint amount) external onlyOwner {     // подумать
        require(marketingShare >= marketingMinted + amount, "a lot of funds");
        mint(msg.sender, amount);
        marketingMinted += amount;
    }

    function airdrop(address[] calldata _members) external onlyOwner {
        uint amount = airdropShare / _members.length;
        for (uint i=0; i<_members.length; i++){
            mint(_members[i], amount);
        }
        airdropShare -= amount * _members.length;
    }

    function addWhitelisters(address[] calldata _whitelisters) external onlyOwner {
        require(MAX_WHITELISTERS >= _whitelisters.length + totalWhitelisters, "too many people");
        totalWhitelisters += _whitelisters.length;
        for (uint i=0; i<_whitelisters.length; i++){
            whitelisters[_whitelisters[i]] = 100;
        }
    }

    function whitelistSale(uint _usdtSum) external {

        require(status == ICOStatus.Whitelist, "another ICO phase");
        require(whitelisters[msg.sender] != 0, "dont have wl or reached limit");
        require(tokenUSDT.allowance(msg.sender, address(this)) >= _usdtSum, "not approve");
        require(_usdtSum <= 100, "too many");

        whitelisters[msg.sender] -= _usdtSum;

        uint countTokens = _usdtSum / WHITELIST_RATE;
        uint mintNow = countTokens * 10 / 100;
        uint lockedMint = countTokens - mintNow;

        require(whitelistShare >= mintNow, "tokens for this stage have run out");
        tokenUSDT.transferFrom(msg.sender, address(this), _usdtSum);
        _mint(msg.sender, mintNow);

        vesting[msg.sender].stage.push("Whitelist");
        vesting[msg.sender].minted += mintNow;
        vesting[msg.sender].locked += lockedMint;
        vesting[msg.sender].nextUnlock.push(block.timestamp + vestingTime);

        whitelistShare -= mintNow;
    }

    function addSeedSalers(address[] calldata _seeds) external onlyOwner { // мб это и не надо
        for (uint i=0; i<_seeds.length; i++){
            seeds[_seeds[i]] = true;
        }
    }

    function seedRound(uint _usdtSum) external {
        require(status == ICOStatus.SeedRound, "another ICO phase");
        require(seeds[msg.sender] == true, "dont have seed ticket");
        require(tokenUSDT.allowance(msg.sender, address(this)) >= _usdtSum, "not approve");

        uint countTokens = _usdtSum / SEEDROUND_RATE;
        uint mintNow = countTokens * 20 / 100;
        uint lockedMint = countTokens - mintNow;

        require(seedRoundShare >= mintNow, "tokens for this stage have run out");
        tokenUSDT.transferFrom(msg.sender, address(this), _usdtSum);
        _mint(msg.sender, mintNow);

        vesting[msg.sender].stage.push("SeedRound");
        vesting[msg.sender].minted += mintNow;
        vesting[msg.sender].locked += lockedMint;
        vesting[msg.sender].nextUnlock.push(block.timestamp + vestingTime);

        seedRoundShare -= mintNow;
        
    }

    function privateSale(uint _usdtSum) external {
        require(status == ICOStatus.PrivateSale, "another ICO phase");
        require(tokenUSDT.allowance(msg.sender, address(this)) >= _usdtSum, "not approve");

        uint countTokens = _usdtSum / PRIVATESALE_RATE;
        uint mintNow = countTokens * 30 / 100;
        uint lockedMint = countTokens - mintNow;

        require(privateSaleShare >= mintNow, "tokens for this stage have run out");
        tokenUSDT.transferFrom(msg.sender, address(this), _usdtSum);
        _mint(msg.sender, mintNow);

        vesting[msg.sender].stage.push("PrivateSale");
        vesting[msg.sender].minted += mintNow;
        vesting[msg.sender].locked += lockedMint;
        vesting[msg.sender].nextUnlock.push(block.timestamp + vestingTime);

        privateSaleShare -= mintNow;
    }

    function publicSale(uint _usdtSum) external {
        require(status == ICOStatus.PublicSale, "another ICO phase");
        require(tokenUSDT.allowance(msg.sender, address(this)) >= _usdtSum, "not approve");
        uint mintNow = _usdtSum / PUBLICSALE_RATE;
        _mint(msg.sender, mintNow);

        publicShare -= mintNow;
    }
}

contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }
}
