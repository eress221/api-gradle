package com.eress.apigradle.repo.board;

import com.eress.apigradle.entity.board.Board;
import com.eress.apigradle.entity.board.Post;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PostJpaRepo extends JpaRepository<Post, Long> {
    List<Post> findByBoard(Board board);
    List<Post> findByBoardOrderByPostIdDesc(Board board);
}
