import { keccak256, toHex, encodePacked } from "viem";
import { MerkleTree } from "merkletreejs";``

const whitelist = [
    "0x0fF93eDfa7FB7Ad5E962E4C0EdB9207C03a0fe02",
    "0x3a7e663c871351BbE7B6dD006cB4A46d75cCe61D",
    "0x696BA93ef4254Da47ff05b6CAa88190dB335F1C3",
];

// const leaves = whitelist.map(addr => keccak256(toHex(addr)));
const leaves = whitelist.map(addr => keccak256(encodePacked(["address"], [addr])));

const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const root = tree.getHexRoot();

console.log("Merkle Root:", root);

whitelist.forEach(addr => {
    const proof = tree.getHexProof(keccak256(encodePacked(["address"], [addr])));
    console.log(`Address: ${addr}, Proof:`, proof);
});

// const leaf = keccak256(toHex("0x0fF93eDfa7FB7Ad5E962E4C0EdB9207C03a0fe02"));
const leaf = keccak256(encodePacked(["address"], ["0x0fF93eDfa7FB7Ad5E962E4C0EdB9207C03a0fe02"]));
console.log("Leaf: ", leaf);

const proof = [
    "0x2d38b9a5083145958e41e8dc4a04a3d9fdb5b30aef77424a93e10c4b954b1a3e",
    "0x1cf4086a8cf15d83df4f50d7fabbaec5f4ea3163eb951ca727ea88e556c3f5b4"
];

const verified = tree.verify(proof, leaf, root);
console.log("Verified: ", verified);


// import { toHex, encodePacked, keccak256 } from 'viem';
// import { MerkleTree } from "merkletreejs";
//
// const users = [
//     { address: "0xD08c8e6d78a1f64B1796d6DC3137B19665cb6F1F", amount: BigInt(10) },
//     { address: "0xb7D15753D3F76e7C892B63db6b4729f700C01298", amount: BigInt(15) },
//     { address: "0xf69Ca530Cd4849e3d1329FBEC06787a96a3f9A68", amount: BigInt(20) },
//     { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824800", amount: BigInt(30) },
// ];
//
// // equal to MerkleDistributor.sol #keccak256(abi.encodePacked(account, amount));
// const elements = users.map((x) =>
//     keccak256(encodePacked(["address", "uint256"], [x.address as `0x${string}` , x.amount]))
// );
//
// // console.log(elements)
//
// const merkleTree = new MerkleTree(elements, keccak256, { sort: true });
//
// const root = merkleTree.getHexRoot();
// console.log("root:" + root);
//
//
// const leaf = elements[3];
// const proof = merkleTree.getHexProof(leaf);
// console.log("proof:" +proof);

// 0xa8532aAa27E9f7c3a96d754674c99F1E2f824800, 30, [0xd24d002c88a75771fc4516ed00b4f3decb98511eb1f7b968898c2f454e34ba23,0x4e48d103859ea17962bdf670d374debec88b8d5f0c1b6933daa9eee9c7f4365b]



