package com.backdoor.game.repository;

import com.backdoor.game.model.entity.Partida;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.Persistence;
import jakarta.persistence.TypedQuery;
import java.util.List;
import java.util.Optional;

public class PartidaRepository {

    // Inicializamos la factoría usando la unidad de persistencia de H2 definida en persistence.xml
    private static final EntityManagerFactory emf = Persistence.createEntityManagerFactory("BackdoorH2PU");

    /**
     * Guarda o actualiza una partida en la base de datos.
     * @param partida
     */
    public void guardar(Partida partida) {
        EntityManager em = emf.createEntityManager();
        try {
            em.getTransaction().begin();
            if (partida.getId() == null) {
                em.persist(partida); // Nueva partida (INSERT)
            } else {
                em.merge(partida);   // Partida existente (UPDATE)
            }
            em.getTransaction().commit();
        } catch (Exception e) {
            if (em.getTransaction().isActive()) {
                em.getTransaction().rollback();
            }
            throw new RuntimeException("Error al guardar la partida en la base de datos", e);
        } finally {
            em.close();
        }
    }

    /**
     * Busca una partida por su ID único.
     * @param id
     * @return
     */
    public Optional<Partida> buscarPorId(Long id) {
        EntityManager em = emf.createEntityManager();
        try {
            Partida partida = em.find(Partida.class, id);
            return Optional.ofNullable(partida);
        } finally {
            em.close();
        }
    }

    /**
     * Busca una partida por el nombre del jugador.
     * @param nombreJugador
     * @return
     */
    public Optional<Partida> buscarPorNombreJugador(String nombreJugador) {
        EntityManager em = emf.createEntityManager();
        try {
            TypedQuery<Partida> query = em.createQuery(
                    "SELECT p FROM Partida p WHERE p.nombreJugador = :nombre", Partida.class);
            query.setParameter("nombre", nombreJugador);
            List<Partida> resultados = query.getResultList();
            return resultados.isEmpty() ? Optional.empty() : Optional.of(resultados.get(0));
        } finally {
            em.close();
        }
    }

    /**
     * Lista todas las partidas guardadas.
     * @return
     */
    public List<Partida> listarTodas() {
        EntityManager em = emf.createEntityManager();
        try {
            TypedQuery<Partida> query = em.createQuery("SELECT p FROM Partida p", Partida.class);
            return query.getResultList();
        } finally {
            em.close();
        }
    }

    /**
     * Cierra la factoría global cuando la aplicación finalice.
     */
    public static void cerrarConexion() {
        if (emf.isOpen()) {
            emf.close();
        }
    }
}