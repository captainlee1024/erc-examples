// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Bank {
    mapping(address => uint256) public balances;

    // 使用双向链表实现
    // 每次按score排序插入对应位置
    struct Node {
        address user;
        uint256 amount;
        address prev;
        address next;
    }

    mapping(address => Node) public nodes;
    address public head;
    uint256 public topCount;
    uint256 constant MAX_TOP = 10;

    event Deposited(address indexed user, uint256 amount);
    event TopUpdated(address indexed user, uint256 amount, bool added);

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;
        updateTopList(msg.sender, balances[msg.sender]);
        emit Deposited(msg.sender, msg.value);
    }

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function getTopDepositors() external view returns (address[] memory, uint256[] memory) {
        address[] memory users = new address[](topCount);
        uint256[] memory amounts = new uint256[](topCount);
        address current = head;
        uint256 index = 0;

        while (current != address(0) && index < topCount) {
            users[index] = nodes[current].user;
            amounts[index] = nodes[current].amount;
            current = nodes[current].next;
            index++;
        }
        return (users, amounts);
    }

    function updateTopList(address user, uint256 newAmount) internal {
        if (nodes[user].amount > 0) {
            removeFromList(user);
        }

        if (head == address(0) || newAmount > nodes[head].amount) {
            insertAtHead(user, newAmount);
        } else if (topCount < MAX_TOP) {
            address current = head;
            while (current != address(0) && nodes[current].amount >= newAmount) {
                current = nodes[current].next;
            }
            if (current == address(0)) {
                insertAtTail(user, newAmount);
            } else {
                insertBefore(current, user, newAmount);
            }
        } else {
            // 链表已满，检查是否替换最小值
            address tail = head;
            while (nodes[tail].next != address(0)) {
                tail = nodes[tail].next;
            }
            if (newAmount > nodes[tail].amount) {
                removeFromList(tail);
                address current = head;
                while (current != address(0) && nodes[current].amount >= newAmount) {
                    current = nodes[current].next;
                }
                if (current == address(0)) {
                    insertAtTail(user, newAmount);
                } else {
                    insertBefore(current, user, newAmount);
                }
            }
        }
    }

    function insertAtHead(address user, uint256 amount) internal {
        nodes[user] = Node(user, amount, address(0), head);
        if (head != address(0)) {
            nodes[head].prev = user;
        }
        head = user;
        topCount++;
        emit TopUpdated(user, amount, true);
    }

    function insertAtTail(address user, uint256 amount) internal {
        if (head == address(0)) {
            insertAtHead(user, amount);
            return;
        }
        address current = head;
        while (nodes[current].next != address(0)) {
            current = nodes[current].next;
        }
        nodes[user] = Node(user, amount, current, address(0));
        nodes[current].next = user;
        topCount++;
        emit TopUpdated(user, amount, true);
    }

    function insertBefore(address before, address user, uint256 amount) internal {
        if (before == address(0)) return;
        address prev = nodes[before].prev;
        nodes[user] = Node(user, amount, prev, before);
        nodes[before].prev = user;
        if (prev != address(0)) {
            nodes[prev].next = user;
        } else {
            head = user;
        }
        topCount++;
        emit TopUpdated(user, amount, true);
    }

    function removeFromList(address user) internal {
        Node memory node = nodes[user];
        if (node.amount == 0) return;
        if (node.prev != address(0)) {
            nodes[node.prev].next = node.next;
        } else {
            head = node.next;
        }
        if (node.next != address(0)) {
            nodes[node.next].prev = node.prev;
        }
        delete nodes[user];
        topCount--;
        emit TopUpdated(user, node.amount, false);
    }
}
