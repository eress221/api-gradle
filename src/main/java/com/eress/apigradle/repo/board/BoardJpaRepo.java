package com.eress.apigradle.repo.board;

import com.eress.apigradle.entity.board.Board;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BoardJpaRepo extends JpaRepository<Board, Long> {
    Board findByName(String name);
}
