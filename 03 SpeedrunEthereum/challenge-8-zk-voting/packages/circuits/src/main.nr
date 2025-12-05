use std::hash::poseidon::bn254::hash_1;
use std::hash::poseidon::bn254::hash_2;
// Checkpoint 4 //////
use binary_merkle_root::binary_merkle_root;

fn main(
    // public inputs
    nullifier_hash: pub Field,
    // private inputs
    nullifier: Field,
    secret: Field,
    // Checkpoint 4 //////
    // public inputs
    root: pub Field,
    vote: pub bool,
    depth: pub u32,
    // private inputs
    index: Field,
    // max of 2^16 leaves --> 65536 leaves
    siblings: [Field; 16],
) {
    // Checkpoint 3 //////
    let computed_nullifier_hash: Field = hash_1([nullifier]);
    assert(computed_nullifier_hash == nullifier_hash);

    let commitment: Field = hash_2([nullifier, secret]);

    // Checkpoint 4 //////
    let mut siblings_num = 0;
    for i in 0..siblings.len() {
        if siblings[i] != 0 {
            siblings_num += 1;
        }
    }
    assert(depth <= siblings.len());

    let index_bits: [u1; 16] = index.to_le_bits();

    let computed_root = binary_merkle_root(hash_2, commitment, depth, index_bits, siblings);
    assert(computed_root == root);

    // just vote binding, to prevent compiler warnings
    let vote_field = vote as Field;
    assert((vote_field * vote_field) == vote_field);
}