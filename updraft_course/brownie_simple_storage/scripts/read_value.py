from brownie import SimpleStorage, accounts, config

simple_storage = SimpleStorage[-1]
print(simple_storage.retrieve())
