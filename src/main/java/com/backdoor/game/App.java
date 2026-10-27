package com.backdoor.game;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.Persistence;
import com.backdoor.game.model.entity.Partida;

public class App {
    public static void main(String[] args) {
        System.out.println(">>> Arrancando motor de persistencia Backdoor...");

        // 1. Inicializamos la factoría usando la unidad de persistencia de H2
        EntityManagerFactory emf = Persistence.createEntityManagerFactory("BackdoorH2PU");
        EntityManager em = emf.createEntityManager();

        try {
            // 2. Abrimos una transacción
            em.getTransaction().begin();

            // 3. Creamos una partida nueva de prueba
            Partida nuevaPartida = new Partida("Angela");

            // 4. Persistimos el objeto (Hibernate genera el INSERT SQL automáticamente)
            em.persist(nuevaPartida);

            // 5. Confirmamos los cambios
            em.getTransaction().commit();

            System.out.println(">>> ¡Partida guardada con éxito en la base de datos H2!");

        } catch (Exception e) {
            if (em.getTransaction().isActive()) {
                em.getTransaction().rollback();
            }
            e.printStackTrace();
        } finally {
            em.close();
            emf.close();
        }
    }
}
