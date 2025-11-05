const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const { setDoc, doc, getDoc } = require("firebase/firestore");

(async () => {
  const testEnv = await initializeTestEnvironment({
    projectId: "billwise-test",
    firestore: { rules: require("fs").readFileSync("firestore.rules", "utf8") },
  });

  const alice = testEnv.authenticatedContext("alice");
  const bob   = testEnv.authenticatedContext("bob");

  const aliceDb = alice.firestore();
  const bobDb   = bob.firestore();

  // Alice: should succeed
  const aliceDoc = doc(aliceDb, "Bills/testBill");
  await assertSucceeds(setDoc(aliceDoc, { user_id: "alice", title: "My Bill" }));
  await assertSucceeds(getDoc(aliceDoc));

  // Bob: should fail reading Alice’s bill
  await assertFails(getDoc(doc(bobDb, "Bills/testBill")));

  console.log("✅ Security Rules Test: PASSED");
  await testEnv.cleanup();
})();