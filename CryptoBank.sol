pragma solidity ^0.7.0;

contract CryptoBank {
    // vars
    uint public accountsNo;
    uint private _bankBalance;
    address private _bankAddr;
    
    // uid generator
    uint uidDigits = 8;
    uint uidModulus = 10 ** uidDigits;
    
    constructor() {
        _bankAddr = msg.sender;
    }
    
    // events
    event actionAccountCreated(string _fName, string _lName, uint uid);
    
    event actionDeposit(uint accountId, uint balance);
    
    event action_Transfer(uint _from, uint _to, uint amount);
    
    event action_BlockAcct(uint _account);
    
    event action_DeleteAccount(uint _account);
    
    // structs
    struct Account {
        string firstName;
        string lastName;
        uint256 uid;
        address owner;
        uint256 balance;
        bool isBlocked;
        bool hasLoan;
    }
    
    // mappings
    mapping(address => uint256[]) public clientAccounts;
    mapping(uint256 => Account) accounts;
    
    // modifiers
    modifier isOwner(uint uid) {
        uint[] memory c_Accounts = clientAccounts[msg.sender];
        bool hasAccount = false;
        for (uint i = 0; i < c_Accounts.length; i++) {
            if (uid == c_Accounts[i]) {
                hasAccount = true;
            } 
        }
        require(hasAccount == true, To make this operation, you have to be the owner of the account.);
        _;
    }
    
    modifier isNotBlocked(uint _from) {
        require(accounts[_from].isBlocked == false, The account is blocked to make transfers.);
        _;
    }
    
    modifier sufficientBalance(uint _from, uint amount) {
        require(accounts[_from].balance > amount, Insufficient funds. Please deposit more funds to make this operation.);
        _;
    }
    
    modifier accountsExist(uint _to, uint _from) {
        require(accounts[_to].uid != uint256(0) && accounts[_from].uid != uint256(0), One of the accounts does not exist.);
        _;
    }
    
    modifier accountExists(uint _acct) {
        require(accounts[_acct].uid != uint256(0), The account does not exist.);
        _;
    }
    
    modifier isBank {
        require(msg.sender == _bankAddr, Only the bank can make this operation.);
        _;
    }
    
    // functions
    function createAccount(string memory _fName, string memory _lName) public {
        bytes memory _seed = abi.encodePacked(_fName, _lName, block.timestamp);
        uint rand = uint(keccak256(_seed));
        uint randomId = rand % uidModulus;
        
        accounts[randomId] = Account({
            firstName: _fName,
            lastName: _lName,
            uid: randomId,
            balance: 0.0,
            isBlocked: false,
            hasLoan: false,
            owner: msg.sender
        });
        
        uint[] storage cAccounts = clientAccounts[msg.sender];
        cAccounts.push(randomId);
        accountsNo++;
        emit actionAccountCreated(_fName, _lName, randomId);
    }
    
    function depositToAccount(uint accountId) public payable {
        uint256 amount = msg.value;
        payable(_bankAddr).transfer(amount);
        accounts[accountId].balance += accounts[accountId].balance + amount;
        emit actionDeposit(accountId, accounts[accountId].balance);
    }
    
    function transferToAccount(uint _from, uint _to, uint amount) 
        public 
        payable 
        isOwner(_from)
        accountsExist(_from, _to)
        isNotBlocked(_from)
        sufficientBalance(_from, amount) 
    {
        accounts[_from].balance -= amount;
        accounts[_to].balance += amount;
        emit action_Transfer(_from, _to, amount);
    }
    
    function viewBalance(uint _account) public view isOwner(_account) returns(uint256) {
        return accounts[_account].balance;
    }
    
    function setBlockAccount(uint _account, bool _isBlocked) public isBank {
        if (accounts[_account].isBlocked == true){
            require(_isBlocked != true, The account is already blocked.);
        } else {
            require(_isBlocked != false, The account is already unblocked.);
        }
        accounts[_account].isBlocked = _isBlocked;
        emit action_BlockAcct(_account);
    }
    
    function swapArray(uint[] storage myArray, uint index) internal {
        uint element = myArray[index];
        myArray[index] = myArray[myArray.length - 1];
        delete myArray[myArray.length - 1];
    }
    
    function closeAccount(uint _account) public isBank accountExists(_account) {
        address payable acctOwner = payable(accounts[_account].owner); // owner
        uint acctToDeleteIdx; // helper to index owner's account and update array
        for (uint i = 0; i < clientAccounts[acctOwner].length; i++) {
            if (clientAccounts[acctOwner][i] == _account) {
                acctToDeleteIdx = i; // when the idx is found, update the helper.
            }
        }
        acctOwner.transfer(accounts[_account].balance); // send balance to owner.
        swapArray(clientAccounts[acctOwner], acctToDeleteIdx); // swap positions with the last position to delete locally.
        delete accounts[_account]; // delete from mapping
        emit action_DeleteAccount(_account);
    }
}



