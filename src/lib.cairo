// This BOOKSTORE Contract will
// Add a new book to the bookstore
// Update book information (price and stock)
// Remove a book from the bookstore
// Purchase a book (deduct from stock and balance)
// Get the balance of a user

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Book {
    title: felt252,
    author: felt252,
    price: u256,
    stock: u32, // Use u32 to represent stock quantity
}


#[starknet::interface]
pub trait IBookstore<TContractState> {
    fn add_book(
        ref self: TContractState,
        book_id: felt252,
        title: felt252,
        author: felt252,
        price: u256,
        stock: u32
    );
    fn update_book(ref self: TContractState, book_id: felt252, new_price: u256, new_stock: u32);
    fn get_book(self: @TContractState, book_id: felt252) -> Book;
    fn purchase_book(ref self: TContractState, buyer: felt252, book_id: felt252, quantity: u32);
    fn remove_book(ref self: TContractState, book_id: felt252);
    fn add_funds(ref self: TContractState, buyer: felt252, amount: u256);
    fn get_balance(self: @TContractState, buyer: felt252) -> u256;
}


#[starknet::contract]
pub mod Bookstore {
    use super::{Book, IBookstore};
    use core::starknet::{
        get_caller_address, ContractAddress,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess}
    };

    #[storage]
    pub struct Storage {
        books: Map<felt252, Book>, //map book id => book struct
        balances: Map<felt252, u256>, //map user address => balance   
        store_owner: ContractAddress, // Address of the bookstore owner
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BookAdded: BookAdded,
        BookUpdated: BookUpdated,
        BookRemoved: BookRemoved,
        FundsAdded: FundsAdded,
        BookPurchased: BookPurchased,
    }

    #[derive(Drop, starknet::Event)]
    struct BookAdded {
        book_id: felt252,
        title: felt252,
        author: felt252,
        price: u256,
        stock: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct BookUpdated {
        book_id: felt252,
        new_price: u256,
        new_stock: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct BookRemoved {
        book_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct FundsAdded {
        account: felt252,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct BookPurchased {
        buyer: felt252,
        book_id: felt252,
        quantity: u256,
        total_cost: u256,
    }


    #[constructor]
    fn constructor(ref self: ContractState, store_owner: ContractAddress) {
        self.store_owner.write(store_owner)
    }


    #[abi(embed_v0)]
    impl Bookstore of IBookstore<ContractState> {
        fn add_book(
            ref self: ContractState,
            book_id: felt252,
            title: felt252,
            author: felt252,
            price: u256,
            stock: u32
        ) {
            let store_owner = self.store_owner.read();
            assert(get_caller_address() == store_owner, 'Only storeowner can add books!');

            let new_book = Book { title: title, author: author, price: price, stock: stock, };
            self.books.write(book_id, new_book);

            self
                .emit(
                    BookAdded {
                        book_id: book_id, title: title, author: author, price: price, stock: stock,
                    }
                );
        }
        fn update_book(ref self: ContractState, book_id: felt252, new_price: u256, new_stock: u32) {
            let store_owner = self.store_owner.read();
            assert(get_caller_address() == store_owner, 'Only owner can update books!');

            let book = self.books.read(book_id);
            assert(book.title != 0, 'Book does not exist');

            let updated_book = Book {
                title: book.title, author: book.author, price: new_price, stock: new_stock,
            };
            self.books.write(book_id, updated_book);

            self
                .emit(
                    BookUpdated { book_id: book_id, new_price: new_price, new_stock: new_stock, }
                );
        }
        fn purchase_book(ref self: ContractState, buyer: felt252, book_id: felt252, quantity: u32) {
            let book = self.books.read(book_id);
            assert(book.title != 0, 'Book does not exist');
            assert(book.stock >= quantity, 'Not enough stock available');

            let quantity_u256: u256 = quantity.into();
            let total_cost = book.price * quantity_u256;

            let buyer_balance: u256 = self.balances.read(buyer);
            assert(buyer_balance >= total_cost, 'Insufficient funds');

            self.balances.write(buyer, buyer_balance - total_cost);

            // Update book's stock
            let updated_book = Book {
                title: book.title,
                author: book.author,
                price: book.price,
                stock: book.stock - quantity,
            };
            self.books.write(book_id, updated_book);

            self.emit(BookPurchased { buyer, book_id, quantity: quantity_u256, total_cost, });
        }
        fn add_funds(ref self: ContractState, buyer: felt252, amount: u256) {
            // Check if amount is greater than zero
            assert(amount > 0, 'Amount must be > 0!');
            let current_balance = self.balances.read(buyer);
            // Update balance
            self.balances.write(buyer, current_balance + amount);

            self.emit(FundsAdded { account: buyer, amount });
        }
        fn remove_book(ref self: ContractState, book_id: felt252) {
            // Ownership check
            let caller = get_caller_address();
            assert(caller == self.store_owner.read(), 'Only the owner can remove books');

            // Check if the book exists
            let book = self.books.read(book_id);
            assert(book.title != 0, 'Book does not exist');

            // Remove the book by deleting it from storage
            self.books.write(book_id, Book { title: 0, author: 0, price: 0, stock: 0 });

            // Emit BookRemoved event
            self.emit(BookRemoved { book_id });
        }

        fn get_book(self: @ContractState, book_id: felt252) -> Book {
            let book = self.books.read(book_id);
            assert(book.title != 0, 'Book does not exist');
            return book;
        }
        fn get_balance(self: @ContractState, buyer: felt252) -> u256 {
            let buyer_balance: u256 = self.balances.read(buyer);
            return buyer_balance;
        }
    }
}
