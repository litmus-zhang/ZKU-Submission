// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract Purchase {
    uint public value;
    address payable public seller;
    address payable public buyer;
    uint256 time;

    enum State { Created, Locked, Release, Inactive }
    // The state variable has a default value of the first member, `State.created`
    State public state;

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    /// Only the buyer can call this function.
    error OnlyBuyer();
    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();

    modifier onlyBuyer() {
        if (msg.sender != buyer)
            revert OnlyBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller)
            revert OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_)
            revert InvalidState();
        _;
    }
  //Works with the completePurchase Function
    modifier completeTrx{
        require(
            ((checkStateLock() == true) && 
            ((time + 5 minutes <= block.timestamp) || (msg.sender == buyer) 
            )),
             "Either you are unauthorized or Hold on a bit");
        _;
    }
   

    event Aborted();
    event PurchaseConfirmed();
    event ItemReceived();
    event SellerRefunded();

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort()
        external
        onlySeller
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        external
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        time = block.timestamp;
        buyer = payable(msg.sender);
        state = State.Locked;
    }

    


    function checkStateLock() internal view inState(State.Locked) returns (bool) {
        
        if (state == State.Locked) {
            return true;
            }
            else {
            return false;
            }
    }

//
  

    function completePurchase() 
    external
    completeTrx
   
    {
        require(msg.sender == buyer, "Buyer need to be sure they have received their order");

        //Buyer POV
         emit ItemReceived();
         
        //Updating transaction state (Buyer)
        state = State.Release;
        buyer.transfer(value);

        //Seller POV
        emit SellerRefunded();

        //Updating transaction state
        state = State.Inactive;

        seller.transfer(3 * value);
    }

}