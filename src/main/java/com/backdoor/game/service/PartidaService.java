package com.backdoor.game.service;

import com.backdoor.game.model.entity.Partida;
import com.backdoor.game.repository.PartidaRepository;

import java.util.Optional;

public class PartidaService {

    private final PartidaRepository partidaRepository;

    public PartidaService() {
        this.partidaRepository = new PartidaRepository();
    }

    /**
     * Inicia una nueva partida con los valores por defecto del guion.
     */
    public Partida iniciarNuevaPartida(String nombreJugador) {
        Partida nuevaPartida = new Partida();
        nuevaPartida.setNombreJugador(nombreJugador);
        nuevaPartida.setCreditos(100);       // Créditos iniciales de supervivencia
        nuevaPartida.setDiaActual(1);        // Día 1 en la burocracia
        nuevaPartida.setSospecha(0);         // Nivel de alerta inicial
        nuevaPartida.setConfianzaNadia(50);  // Estado inicial del contacto clave
        nuevaPartida.setIndicios(0);

        // Guardamos directamente en la base de datos H2
        partidaRepository.guardar(nuevaPartida);
        return nuevaPartida;
    }

    /**
     * Guarda el progreso actual de la partida.
     */
    public void guardarProgreso(Partida partida) {
        if (partida.getNombreJugador() == null || partida.getNombreJugador().isEmpty()) {
            throw new IllegalArgumentException("La partida debe tener un nombre de jugador válido para guardarse.");
        }
        partidaRepository.guardar(partida);
    }

    /**
     * Carga una partida existente por el nombre del jugador.
     */
    public Optional<Partida> cargarPartida(String nombreJugador) {
        return partidaRepository.buscarPorNombreJugador(nombreJugador);
    }
}
