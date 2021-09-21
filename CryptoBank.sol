pragma solidity ^0.8.3;

contract CryptoBank {
    // vars
    uint public accountsNo;
    uint public _bankBalance;
    address private _bankAddr;
    
    // uid generator
    uint uidDigits = 8;
    uint uidModulus = 10 ** uidDigits;
    
    // mappings
    mapping(address => uint256) public clientAccounts;
    mapping(uint256 => Account) accounts;
    mapping(uint256 => Loan) approvedLoans;
    
    constructor() {
        _bankAddr = msg.sender;
    }
    
    // events
    event actionAccountCreated(string _fName, string _lName, uint uid);
    
    event actionDeposit(uint accountId, uint balance);
    
    event action_Transfer(uint _from, uint _to, uint amount);
    
    event action_BlockAcct(uint _account);
    
    event action_DeleteAccount(uint _account);
    
    // loan events.
    event loan_Create(uint amount, uint _account, bool isCollateralized);
    
    event loan_RequestCreated(uint amount, uint _account, bool isCollateralized);

    event loan_ApprovedOrRejected(uint _account, bool _decision);
    
    event loan_AmountPayed(uint _account, uint amount);

    event view_NextLoanAmount(uint account, uint amountLoaned);
    
    // structs
    struct Account {
        address owner;
        bool hasLoan;
        bool isBlocked;
        string firstName;
        string lastName;
        uint256 balance;
        uint256 uid;
    }

    struct Loan {
        address owner;
        bool isApproved;
        bool isCollateralized;
        bool isPayed;
        uint account;
        uint256 amountLoaned;
        uint256 collateralQty;
        uint256 endDate;
        uint256 startDate;
        uint256 totalOwned;
        uint256 totalPayed;
    }

    // loan requests
    Loan[] private requestedLoans;

    // modifiers
    modifier isOwner(uint uid) {
        uint id_Account = clientAccounts[msg.sender];
        require(id_Account == uid, "To make this operation, you have to be the owner of the account.");
        _;
    }
    
    modifier isNotBlocked(uint _from) {
        require(accounts[_from].isBlocked == false, "The account is blocked to make transfers.");
        _;
    }
    
    modifier sufficientBalance(uint _from, uint amount) {
        require(accounts[_from].balance > amount, "Insufficient funds. Please deposit more funds to make this operation.");
        _;
    }
    
    modifier accountsExist(uint _to, uint _from) {
        require(accounts[_to].uid != uint256(0) && accounts[_from].uid != uint256(0), "One of the accounts does not exist.");
        _;
    }
    
    modifier accountExists(uint _acct) {
        require(accounts[_acct].uid != uint256(0), "The account does not exist.");
        _;
    }
    
    modifier isBank {
        require(msg.sender == _bankAddr, "Only the bank can make this operation.");
        _;
    }

    modifier bankCanLoan(uint256 loanAmount) {
        require(_bankBalance >= loanAmount, "The bank is out of funds");
        _;
    }

    modifier clientHasLoan(uint256 _account) {
        require(accounts[_account].hasLoan == false, "The client already has a loan");
        _;
    }

    modifier onlyOneAccount {
        require(accounts[clientAccounts[msg.sender]].owner == address(0), "The client already has an account");
        _;
    }
    
    /** functions **/

    // adds accounts to be tested in remix easily.
    function addStagingEnv() public {
        accounts[1111] = Account({
            firstName: 'Juan',
            lastName: 'Perez',
            uid: 1111,
            balance: 0,
            isBlocked: false,
            hasLoan: false,
            owner: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
        });

        accounts[2222] = Account({
            firstName: 'Juan',
            lastName: 'Perez',
            uid: 2222,
            balance: 0,
            isBlocked: false,
            hasLoan: false,
            owner: 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
        });
        accounts[3333] = Account({
            firstName: 'Juan',
            lastName: 'Perez',
            uid: 3333,
            balance: 0,
            isBlocked: false,
            hasLoan: false,
            owner: 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
        });
        clientAccounts[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = 1111;
        clientAccounts[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = 2222;
        clientAccounts[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = 3333;
        accountsNo += 0;
    }

    // adds a dummy loan to test functionality.
    function addDummyLoan() public returns(Loan memory) {
        approvedLoans[12345678] = Loan({
            owner: msg.sender,
            isApproved: true,
            isCollateralized: false,
            isPayed: false,
            account: 12345678,
            amountLoaned: 1000,
            startDate: 1609912800,
            endDate: 1612591200,
            totalPayed: 0,
            // should be calculated initial amount.
            totalOwned: 1100
        });
        return approvedLoans[12345678];
    }
    
    // creates a new account for clients.
    function createAccount(string memory _fName, string memory _lName) public onlyOneAccount {
        bytes memory _seed = abi.encodePacked(_fName, _lName, block.timestamp);
        uint rand = uint(keccak256(_seed));
        uint randomId = rand % uidModulus;
        
        accounts[randomId] = Account({
            firstName: _fName,
            lastName: _lName,
            uid: randomId,
            balance: 0,
            isBlocked: false,
            hasLoan: false,
            owner: msg.sender
        });
        
        clientAccounts[msg.sender] = randomId;
        accountsNo++;
        emit actionAccountCreated(_fName, _lName, randomId);
    }
    
    // deposits real amount to a client's account. 
    // Is strictly payable. 
    function depositToAccount(uint accountId) 
        public payable accountExists(accountId)
    {
        require(msg.value != 0, "Should at least deposit a fraction of a number, not 0.");
        
        uint256 amount = msg.value;
        
        payable(_bankAddr).transfer(amount); // updates the real fungible money in the bank.
        
        _bankBalance += amount; // updates the static amount of bank;
        
        accounts[accountId].balance += accounts[accountId].balance + amount; // updates the user's account.
        
        emit actionDeposit(accountId, accounts[accountId].balance); 
    }
    
    // can transfer balance from one account to the other.
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
    
    // views the balance of an account.
    function viewBalance(uint _account) public view isOwner(_account) returns(uint256) {
        return accounts[_account].balance;
    }
    
    // blocks an account and impedes it from transfering.
    // (ONLY BANK)
    function setBlockAccount(uint _account, bool _isBlocked) public isBank {
        if (accounts[_account].isBlocked == true){
            require(_isBlocked != true, "The account is already blocked.");
        } else {
            require(_isBlocked != false, "The account is already unblocked.");
        }
        accounts[_account].isBlocked = _isBlocked;
        emit action_BlockAcct(_account);
    }
    
    // closes an account and transfers real amount to a client.
    // TODO: if user has a loan pending, the account can't be closed.
    function closeAccount(uint _account) public isBank accountExists(_account) {
        address payable acctOwner = payable(accounts[_account].owner); // owner
        acctOwner.transfer(accounts[_account].balance); // send balance to owner.
        
        delete clientAccounts[acctOwner]; // delete from owner - acct.
        delete accounts[_account]; // delete from mapping

        emit action_DeleteAccount(_account);
    }

    /**
     * checks the next loan request in the loans queue.
     */ 
    function viewNextLoanRequest()
        public
        isBank
        view
        returns(uint, uint)
    {
        Loan storage newLoan = requestedLoans[requestedLoans.length - 1];
        return (newLoan.account, newLoan.amountLoaned);
    }
    
    /**
    * calculates the loan amount with the total interest.
    */
    function calculateLoanAmount(uint _loanQty, uint interest) 
        public pure returns (uint256) 
    {
        return _loanQty + ((_loanQty * interest) / 100);
    }

    /**
    *    requests a simple loan
    */
    function requestLoan(
        uint amount, uint _account
    )
        public 
        clientHasLoan(_account)
        bankCanLoan(amount)
        isOwner(_account)
    {
        // calculates the value of the owned amount with interest
        uint finalOwnedAmount = calculateLoanAmount(amount, 10);
        
        // adds new loan to requests.
        requestedLoans.push(Loan({
            owner: msg.sender,
            isApproved: false,
            isCollateralized: false,
            isPayed: false,
            account: _account,
            amountLoaned: amount,
            startDate: 0,
            endDate: 0,
            totalPayed: 0,
            // should be calculated initial amount.
            collateralQty: 0,
            totalOwned: finalOwnedAmount
        }));

        emit loan_RequestCreated(amount, _account, false);
    }

    /**
    *    requests an overcollateralized loan
    */
    function requestCollateralizedLoan(
        uint amount, uint _account, uint collateralAmount
    )
        public 
        clientHasLoan(_account)
        bankCanLoan(amount)
        isOwner(_account)
    {
        // calculates the value of the owned amount with interest
        uint finalOwnedAmount = calculateLoanAmount(amount, 1); // calculates the owned amount for the loan.
        uint collateralQty = calculateLoanAmount(amount, 200); // calculates the collateral to check if it's correct.

        require(collateralQty == collateralAmount, "The collateral amount is incorrect, please leave 200% of the requested loan.");
        // adds new loan to requests.
        requestedLoans.push(Loan({
            owner: msg.sender,
            isApproved: false,
            isCollateralized: true,
            isPayed: false,
            account: _account,
            amountLoaned: amount,
            startDate: 0,
            endDate: 0,
            totalPayed: 0,
            // should be calculated initial amount.
            collateralQty: collateralAmount,
            totalOwned: finalOwnedAmount
        }));

        emit loan_RequestCreated(amount, _account, false);
    }

    /**
    *    approves or rejects the next request in queue.
    *   (ONLY BANK)
    */
    function approveOrRejectLoan(bool _decision) 
        public
        isBank
        returns (bool)
    {   
        Loan memory loan = requestedLoans[requestedLoans.length - 1]; // gets next loan to approve from queue.
        if (_decision == true) {
            loan.startDate = block.timestamp; 
            loan.endDate = block.timestamp + 30 days;
            loan.isApproved = true;

            // adds the loan to the mapping.
            approvedLoans[loan.account] = loan;

            // adds the loaned amount to the requestor.
            accounts[loan.account].balance += loan.amountLoaned;
            requestedLoans.pop();
        } else {
            requestedLoans.pop();
        }
        emit loan_ApprovedOrRejected(loan.account, _decision);

        return _decision;
    }

    /** loan views. **/
     
    function viewDaysSinceStart(uint256 _account) 
        public
        view
        returns(uint, uint, uint)
    {
        Loan storage loan = approvedLoans[_account];
        uint daysSinceStart = (loan.endDate - loan.startDate) / 30 days;
        return (loan.endDate, loan.startDate, daysSinceStart);
    }

    function viewMonthsDue(uint256 _account) 
        public
        view
        returns(uint)
    {
        require(approvedLoans[_account].account == _account, "Please use a valid loan to view the data.");
        Loan storage loan = approvedLoans[_account];
        uint monthsDue = ((block.timestamp - loan.endDate) / 1 days) / 30;
        return monthsDue;
    }

    function viewAmountPayedLoan() 
        public
        view
    {
        return loans[clientAccounts[msg.sender]].totalPayedLoan;
    }

    function viewAmountOwned() 
        public
        view
    {
        return loans[clientAccounts[msg.sender]].totalOwned;
    }

    // close loan deal and delete it from contract.
    function closeLoanDeal(uint _account)
        internal
    {
        // if loan was overcollateralized, then return the collateral amount to user.
        if (approvedLoans[_account].isCollateralized == true) {
            accounts[_account].balance += approvedLoans[_account].collateralQty;
        }
        accounts[_account].hasLoan = false;
        delete approvedLoans[_account];
    }

    // pay a loan, check if there's a delay in payments 
    // and add compound interest to owned amount.
    function payLoan(uint256 payAmount, uint256 _account) 
        public
        payable
        isOwner(_account)
    {  
        Loan storage loan = approvedLoans[_account];
        // checks that the account has a loan and exists.
        require(loan.owner msg.sender, "Only the owner can pay his loan or the account does not exist");
        // checks that the client is not paying more than owned.
        require(payAmount <= loan.totalOwned, "The amount to pay should be smaller or equal to the total owned amount.");
        // gets the amount of days a user is late
        (,,uint daysSinceStart) = viewDaysSinceStart(_account);
        // if there are 0 days left then the loan is late due.
        bool isLate = daysSinceStart == 0;
        // removes qty amount from account.
        accounts[_account].balance -= payAmount;
            
        // If user has not yet paid the loan and is late
        // then a compound interest is added adding --> loanedAmount + (n (months late) interest % ... , n - 1)
        if (isLate == true) {
            uint monthsDue = viewMonthsDue(_account);
            if (loan.isCollateralized == true) {
                // add collateralized interest.
                loan.totalOwned += calculateLoanAmount(loan.amountLoaned, 1 * monthsDue);
                loan.totalOwned -= payAmount;
                loan.totalPayed += payAmount;

            } else {
                // add compount interest amount * days late. 
                loan.totalOwned += calculateLoanAmount(loan.amountLoaned, 10 * monthsDue);
                loan.totalOwned -= payAmount;
                loan.totalPayed += payAmount;
            }
            // updates due date of loan liquidation.
            loan.endDate = ((monthsDue * 30) * 1 days) + loan.startDate;
        } else {
            loan.totalOwned -= payAmount;
            loan.totalPayed += payAmount;
        }

        emit loan_AmountPayed(_account, payAmount);

        if (loan.totalOwned == 0) {
            closeLoanDeal(_account); // closes the loan deal and marks the loan as payed.
        }
    }
    

}