defmodule Maru.Builder.DSLsTest do
  use ExUnit.Case, async: true

  alias Maru.Struct.Resource
  alias Maru.Struct.Plug, as: MaruPlug

  test "prefix" do
    defmodule PrefixTest1 do
      use Maru.Builder
      prefix :foo

      def r, do: @resource
    end

    defmodule PrefixTest2 do
      use Maru.Builder
      prefix "foo/:bar"

      def r, do: @resource
    end

    defmodule PrefixTest3 do
      use Maru.Router
      prefix :foo

      namespace :bar do
        prefix :baz

        def r, do: @resource
      end
    end

    assert %Resource{path: ["foo"]} = PrefixTest1.r
    assert %Resource{path: ["foo", :bar]} = PrefixTest2.r
    assert %Resource{path: ["foo", "bar", "baz"]} = PrefixTest3.r
  end

  test "version" do
    defmodule VersionTest1 do
      use Maru.Builder

      version "v1"
      def v, do: @resource.version
    end

    defmodule VersionTest2 do
      use Maru.Builder

      version "v1" do
        def v1, do: @resource.version
      end

      version "v2" do
        def v2, do: @resource.version
      end
    end

    defmodule VersionTest3 do
      use Maru.Builder

      version "v2", extend: "v1", at: VersionTest1
      def v, do: @resource.version
      def e, do: @extend
    end

    assert "v1" == VersionTest1.v

    assert "v1" == VersionTest2.v1
    assert "v2" == VersionTest2.v2

    assert "v2" == VersionTest3.v
    assert {"v2", [extend: "v1", at: VersionTest1]} == VersionTest3.e
  end

  test "helpers" do
    defmodule H do
      def __shared_params__, do: [:x]
    end

    defmodule HelpersTest1 do
      use Maru.Builder

      helpers Maru.Builder.DSLsTest.H

      def s, do: @shared_params
      def h, do: @resource.helpers
    end

    defmodule HelpersTest2 do
      use Maru.Builder

      helpers do
        import A1
        import A2, only: [x: 0]
        alias B1
        alias B2, as: BB2
        require C1
        require C2, as: CC2
      end

      def h, do: @resource.helpers
    end

    defmodule HelpersTest3 do
      use Maru.Builder

      helpers do
        def f,  do: fp
        defp fp, do: :func

        params :x do
        end
      end

      def s, do: @shared_params
    end

    assert [:x] = HelpersTest1.s
    assert [{:import, _, [Maru.Builder.DSLsTest.H]}] = HelpersTest1.h
    assert [
      {:import,  _, [{:__aliases__, _, [:A1]}]},
      {:import,  _, [{:__aliases__, _, [:A2]}, [only: [x: 0]]]},
      {:alias,   _, [{:__aliases__, _, [:B1]}]},
      {:alias,   _, [{:__aliases__, _, [:B2]}, [as: {:__aliases__, _, [:BB2]}]]},
      {:require, _, [{:__aliases__, _, [:C1]}]},
      {:require, _, [{:__aliases__, _, [:C2]}, [as: {:__aliases__, _, [:CC2]}]]},
    ] = HelpersTest2.h
    assert :func = HelpersTest3.f
    assert [x: nil] = HelpersTest3.s
  end

  test "desc" do
    defmodule DescTest do
      use Maru.Router

      desc "desc test"

      def d, do: @desc
    end

    assert "desc test" = DescTest.d
  end


  test "mount" do
    defmodule Mounted do
      def __routes__ do
        [%Maru.Struct.Route{}]
      end
    end

    defmodule MountTest do
      use Maru.Router

      mount Maru.Builder.DSLsTest.Mounted

      def m, do: @mounted
    end

    assert [%Maru.Struct.Route{}] = MountTest.m
  end


  test "plug" do
    defmodule PlugTest do
      use Maru.Router

      plug :a
      plug :a when 1 > 0
      plug :a, [opts: true] when 1 > 0
      plug P
      plug P when 1 > 0
      plug P, "options" when 1 > 0

      def p, do: @resource.plugs
    end

    assert [
      %MaruPlug{guards: true, name: nil, options: [], plug: :a},
      %MaruPlug{guards: {:>, _, [1, 0]}, name: nil, options: [], plug: :a},
      %MaruPlug{guards: {:>, _, [1, 0]}, name: nil, options: [opts: true], plug: :a},
      %MaruPlug{guards: true, name: nil, options: [], plug: P},
      %MaruPlug{guards: {:>, _, [1, 0]}, name: nil, options: [], plug: P},
      %MaruPlug{guards: {:>, _, [1, 0]}, name: nil, options: "options", plug: P}
    ] = PlugTest.p
  end

  test "plug_overridable" do
    defmodule PlugOverridableTest do
      use Maru.Router

      plug :a
      plug_overridable :name, :b
      plug P
      plug_overridable :name, :c

      pipeline do
        plug P
        plug_overridable :name, :d
        plug_overridable :x, :a
      end
      def p1, do: @resource.plugs
      def p2, do: MaruPlug.merge(@resource.plugs, @plugs)
    end

    assert [
      %MaruPlug{name: nil, plug: :a},
      %MaruPlug{name: :name, plug: :c},
      %MaruPlug{name: nil, plug: P},
    ] = PlugOverridableTest.p1

    assert [
      %MaruPlug{name: nil, plug: :a},
      %MaruPlug{name: :name, plug: :d},
      %MaruPlug{name: nil, plug: P},
      %MaruPlug{name: nil, plug: P},
      %MaruPlug{name: :x, plug: :a},
    ] = PlugOverridableTest.p2
  end

end
