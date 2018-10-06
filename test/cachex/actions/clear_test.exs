defmodule Cachex.Actions.ClearTest do
  use CachexCase

  # This test verifies that a cache can be successfully cleared. We fill the cache
  # and clear it, verifying that the entries were removed successfully. We also
  # ensure that hooks were updated with the correct values.
  test "clearing a cache of all items" do
    # create a forwarding hook
    hook = ForwardHook.create()

    # create a test cache
    cache = Helper.create_cache([ hooks: [ hook ] ])

    # fill with some items
    { :ok, true } = Cachex.put(cache, 1, 1)
    { :ok, true } = Cachex.put(cache, 2, 2)
    { :ok, true } = Cachex.put(cache, 3, 3)

    # clear all hook
    Helper.flush()

    # clear the cache
    result = Cachex.clear(cache)

    # 3 items should have been removed
    assert(result == { :ok, 3 })

    # verify the hooks were updated with the clear
    assert_receive({ { :clear, [[]] }, ^result })

    # verify the size call never notified
    refute_receive({ {  :size, [[]] }, ^result })

    # retrieve all items
    value1 = Cachex.get(cache, 1)
    value2 = Cachex.get(cache, 2)
    value3 = Cachex.get(cache, 3)

    # verify the items are gone
    assert(value1 == { :ok, nil })
    assert(value2 == { :ok, nil })
    assert(value3 == { :ok, nil })
  end

  # This test verifies that the distributed router correctly controls
  # the clear/2 action in such a way that it can clean both a local
  # node as well as a remote node. We don't have to check functionality
  # of the entire action; just the actual routing of the action to the
  # target node(s) is of interest here.
  @tag distributed: true
  test "clearing a cache cluster of all items" do
    # create a new cache cluster for cleaning
    { cache, _nodes } = Helper.create_cache_cluster(2)

    # we know that 1 & 2 hash to different nodes
    { :ok, true } = Cachex.put(cache, 1, 1)
    { :ok, true } = Cachex.put(cache, 2, 2)

    # retrieve the cache size, should be 2
    size1 = Cachex.size(cache)

    # check the size of the cache
    assert(size1 == { :ok, 2 })

    # clear just the local cache to start with
    clear1 = Cachex.clear(cache, [ local: true ])

    # check the result removed 1
    assert(clear1 == { :ok, 1 })

    # fetch the size of local and remote
    size2 = Cachex.size(cache, [ local: true ])
    size3 = Cachex.size(cache, [ local: false ])

    # check that the local is 0, remote is 1
    assert(size2 == { :ok, 0 })
    assert(size3 == { :ok, 1 })

    # clear the entire cluster at this point
    clear2 = Cachex.clear(cache)

    # check the result removed 1
    assert(clear2 == { :ok, 1 })

    # fetch the size of local and remote (again)
    size4 = Cachex.size(cache, [ local: true ])
    size5 = Cachex.size(cache, [ local: false ])

    # check that both are now 0
    assert(size4 == { :ok, 0 })
    assert(size5 == { :ok, 0 })
  end
end
