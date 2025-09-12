defmodule Modkit.SnakeCaseTest do
  alias Modkit.SnakeCase
  use ExUnit.Case, async: true

  describe "basic tests" do
    test "basic snake casing" do
      assert "a" = SnakeCase.to_snake("A")
      assert "a" = SnakeCase.to_snake(A)
      assert "ab" = SnakeCase.to_snake(AB)
      assert "ab_c" = SnakeCase.to_snake(AbC)
      assert "ab2_cd" = SnakeCase.to_snake(AB2CD)
    end
  end

  describe "custom names support" do
    test "names are kept together" do
      # No change on this since multiple uppercase letters are kept as one word
      # without the last capital
      assert "kpi_helper" = SnakeCase.to_snake(KPIHelper)
      assert "kpi_helper" = SnakeCase.to_snake(KPIHelper, names: [KPI: "kpi"])
    end

    test "names with plural are tied to the s" do
      # No change on this since multiple uppercase letters are kept as one word
      # without the last capital
      assert "kp_is_helper" = SnakeCase.to_snake(KPIsHelper)
      assert "kpis_helper" = SnakeCase.to_snake(KPIsHelper, names: [KPI: "kpi"])
    end

    test "names can be a map" do
      assert "kpis_helper" = SnakeCase.to_snake(KPIsHelper, names: %{KPI: "kpi"})
    end

    test "names can be strings" do
      assert "kpis_helper" = SnakeCase.to_snake(KPIsHelper, names: %{"KPI" => "kpi"})
    end

    test "names can contain lowercase" do
      # No change on this since multiple uppercase letters are kept as one word
      # without the last capital
      assert "rabbit_mq_helper" = SnakeCase.to_snake(RabbitMQHelper)
      assert "rabbitmq_helper" = SnakeCase.to_snake(RabbitMQHelper, names: [RabbitMQ: "rabbitmq"])
    end

    test "names are not mixed with other uppercase" do
      assert "httpkpiapi" = SnakeCase.to_snake(HTTPKPIAPI)
      assert "http_kpi_api" = SnakeCase.to_snake(HTTPKPIAPI, names: [KPI: "kpi"])
    end

    test "numbers are handled properly" do
      assert "k8s_helper" = SnakeCase.to_snake(K8sHelper)
      assert "httpk8_sapi" = SnakeCase.to_snake(HTTPK8SAPI)
      assert "k8s_helper" = SnakeCase.to_snake(K8sHelper, names: [K8S: "k8s"])
      assert "http_k8s_api" = SnakeCase.to_snake(HTTPK8SAPI, names: [K8S: "k8s"])
    end
  end

  describe "double underscore removal" do
    test "underscores from module names" do
      assert "a_b" = SnakeCase.to_snake(A_B)
      assert "a_b" = SnakeCase.to_snake(A_____B)
    end

    test "undescores from name insertion" do
      assert "helper_for_kpis" = SnakeCase.to_snake(HelperForKPIs, names: [KPI: "__kpi"])
    end
  end
end
