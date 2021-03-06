// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -enforce-exclusivity=none -emit-sil -Onone %s -o %t/Onone.sil
// RUN: %target-sil-opt %t/Onone.sil -inline -assume-parsing-unqualified-ownership-sil -o %t/inlined.sil
// RUN: %FileCheck %s --check-prefix=INLINE < %t/inlined.sil
// RUN: not %target-sil-opt -enable-sil-verify-all %t/inlined.sil -enforce-exclusivity=unchecked -diagnose-static-exclusivity -assume-parsing-unqualified-ownership-sil -o /dev/null 2> %t/err.txt
// RUN: %FileCheck %s --check-prefix=DIAGNOSE < %t/err.txt

public protocol SomeP {
  var someV: Int { get set }
}
public func assignNonConflict(_ p: inout SomeP) {
  p.someV = p.someV
}
struct Some : SomeP {
  var someV = 0
}

// After inlining we have nested access to an existential property.
// The other access passes the existential @inout.
//
// The passed argument is accessed again inside assignNonConflict to unwrap the
// existential.
//
// INLINE-LABEL: $S5Onone16testNestedAccessyyF
// INLINE: [[OUTER:%.*]] = begin_access [modify] [static] %0 : $*SomeP
// INLINE: [[INNERMOD:%.*]] = begin_access [modify] [static] [[OUTER]] : $*SomeP
// INLINE: %{{.*}} = open_existential_addr mutable_access [[INNERMOD]] : $*SomeP to $*@opened("{{.*}}") SomeP
// INLINE: [[INNERREAD:%.*]] = begin_access [read] [static] [[OUTER]] : $*SomeP
//
// DIAGNOSE: error: overlapping accesses, but modification requires exclusive access; consider copying to a local variable
// DIAGNOSE: %{{.*}} = begin_access [modify] [static] %0 : $*SomeP
// DIAGNOSE: %{{.*}} = begin_access [read] [static] %0 : $*SomeP
// DIAGNOSE: %{{.*}} = begin_access [modify] [static] %{{.*}} : $*SomeP
// DIAGNOSE: %{{.*}} = begin_access [read] [static] %{{.*}} : $*SomeP
public func testNestedAccess() {
  var s: SomeP = Some()
  assignNonConflict(&s)
}
