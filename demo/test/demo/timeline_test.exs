defmodule Demo.TimelineTest do
  use Demo.DataCase

  alias Demo.Timeline

  describe "posts" do
    alias Demo.Timeline.Post

    import Demo.TimelineFixtures

    @invalid_attrs %{body: nil, likes_count: nil, repost_count: nil, photo_locations: nil}

    test "list_posts/0 returns all posts" do
      post = post_fixture()
      assert Timeline.list_posts() == [post]
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      assert Timeline.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      valid_attrs = %{
        body: "some body",
        likes_count: 42,
        repost_count: 42,
        photo_locations: ["option1", "option2"]
      }

      assert {:ok, %Post{} = post} = Timeline.create_post(valid_attrs)
      assert post.body == "some body"
      assert post.likes_count == 42
      assert post.repost_count == 42
      assert post.photo_locations == ["option1", "option2"]
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Timeline.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()

      update_attrs = %{
        body: "some updated body",
        likes_count: 43,
        repost_count: 43,
        photo_locations: ["option1"]
      }

      assert {:ok, %Post{} = post} = Timeline.update_post(post, update_attrs)
      assert post.body == "some updated body"
      assert post.likes_count == 43
      assert post.repost_count == 43
      assert post.photo_locations == ["option1"]
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Timeline.update_post(post, @invalid_attrs)
      assert post == Timeline.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Timeline.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Timeline.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Timeline.change_post(post)
    end
  end
end
