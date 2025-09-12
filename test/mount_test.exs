defmodule Modkit.MountTest do
  alias Modkit.Mount
  use ExUnit.Case, async: true

  test "mount points can be defined" do
    assert {:ok, _} = Mount.define([])
    assert {:ok, _} = Mount.define([{AAA, "lib/aaa"}])

    assert {:error, %ArgumentError{message: ":mount config option must be a list of tuples" <> _}} =
             Mount.define(:hello)

    assert {:error, %ArgumentError{message: "invalid point in :mount config option, got: " <> _}} =
             Mount.define([:hello])

    assert {:error, %ArgumentError{message: "invalid point in :mount config option, got: " <> _}} =
             Mount.define([{AAA, "hello", flavor: :dunk}])
  end

  test "a point can be found for a module" do
    {:ok, mount} = Mount.define([])
    assert {:error, :not_mounted} = Mount.resolve(mount, AAA)

    {:ok, mount} = Mount.define([{AAA, "lib/aaa"}])
    assert {:error, :not_mounted} = Mount.resolve(mount, BBB)
    assert {:ok, %{prefix: AAA}} = Mount.resolve(mount, AAA)
  end

  test "order of mount is not important, automatic precedence is handled" do
    # we test both orders

    check = fn points ->
      {:ok, mount} = Mount.define(points)

      assert {:ok, %{prefix: AAA}} = Mount.resolve(mount, AAA)
      assert {:ok, %{prefix: AAA.BBB}} = Mount.resolve(mount, AAA.BBB)
    end

    # less precision first
    check.([
      {AAA, "lib/aaa"},
      {AAA.BBB, "lib/aaa/bbb"}
    ])

    # more precision first
    check.([
      {AAA.BBB, "lib/aaa/bbb"},
      {AAA, "lib/aaa"}
    ])
  end

  test "flavour is not important when resolving" do
    check = fn points ->
      {:ok, mount} = Mount.define(points)

      assert {:ok, %{prefix: AAA}} = Mount.resolve(mount, AAA)
      assert {:ok, %{prefix: AAA.BBB}} = Mount.resolve(mount, AAA.BBB)
    end

    check.([
      {AAA, "lib/aaa", flavor: :phoenix},
      {AAA.BBB, "lib/aaa/bbb"}
    ])

    check.([
      {AAA, "lib/aaa"},
      {AAA.BBB, "lib/aaa/bbb", flavor: :phoenix}
    ])

    check.([
      {AAA.BBB, "lib/aaa/bbb", flavor: :phoenix},
      {AAA, "lib/aaa"}
    ])

    check.([
      {AAA.BBB, "lib/aaa/bbb"},
      {AAA, "lib/aaa", flavor: :phoenix}
    ])
  end

  test "a mount point can give a new path" do
    {:ok, mount} = Mount.define([{AAA, "lib/aaa"}])

    assert {:ok, "lib/aaa.ex"} = Mount.preferred_path(mount, AAA)
    assert {:ok, "lib/aaa/bbb.ex"} = Mount.preferred_path(mount, AAA.BBB)
    assert {:ok, "lib/aaa/bbb/hello_world.ex"} = Mount.preferred_path(mount, AAA.BBB.HelloWorld)
  end

  test "the phoenix flavor has special cases" do
    {:ok, mount} = Mount.define([{App, "lib/app", flavor: :phoenix}])

    check = fn expected_path, module ->
      assert {:ok, expected_path} == Mount.preferred_path(mount, module)
    end

    check.("lib/app.ex", App)
    check.("lib/app/other.ex", App.Other)

    check.("lib/app/views/some_view.ex", App.SomeView)
    check.("lib/app/controllers/some_controller.ex", App.SomeController)
    check.("lib/app/components/multi_components.ex", App.MultiComponents)
    check.("lib/app/components/some_component.ex", App.SomeComponent)
    check.("lib/app/components/layouts.ex", App.Layouts)
    check.("lib/app/live/some_live.ex", App.SomeLive)
    check.("lib/app/controllers/some_html.ex", App.SomeHTML)
    check.("lib/app/controllers/some_json.ex", App.SomeJSON)
    check.("lib/app/channels/some_channel.ex", App.SomeChannel)
    check.("lib/app/channels/some_socket.ex", App.SomeSocket)
  end

  test "the mix task flavor uses dots for the last segment" do
    {:ok, mount} = Mount.define([{Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}])

    check = fn expected_path, module ->
      assert {:ok, expected_path} == Mount.preferred_path(mount, module)
    end

    check.("lib/mix/tasks/my_task.ex", Mix.Tasks.MyTask)
    check.("lib/mix/tasks/my.task.ex", Mix.Tasks.My.Task)
  end

  test "a mounted prefix ignores shorter modules" do
    {:ok, mount} = Mount.define([{AAA.BBB, "lib/aaa/bbb"}])

    assert {:error, :not_mounted} = Mount.preferred_path(mount, AAA)
  end

  test "erlang modules are safely ingored" do
    assert {:ok, mount} = Mount.define([])
    assert {:error, :not_elixir} = Mount.preferred_path(mount, :crypto)
  end

  test "it is possible to mount a prefix as :ignore" do
    assert {:ok, mount} = Mount.define([{AAA, :ignore}])
    assert :ignore = Mount.resolve(mount, AAA)
  end

  test "mount supports the :names option" do
    assert {:ok, mount} = Mount.define([{MyApp, "lib/my_app"}], names: [RabbitMQ: "rabbitmq"])

    check = fn expected_path, module ->
      assert {:ok, expected_path} == Mount.preferred_path(mount, module)
    end

    check.("lib/my_app/consumers/rabbitmq_consumer.ex", MyApp.Consumers.RabbitMQConsumer)
  end
end
