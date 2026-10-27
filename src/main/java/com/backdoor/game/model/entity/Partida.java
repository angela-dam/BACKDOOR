package com.backdoor.game.model.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "partidas")
public class Partida {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "nombre_jugador", nullable = false)
    private String nombreJugador;

    @Column(name = "dia_actual")
    private int diaActual;

    @Column(name = "creditos")
    private int creditos;

    @Column(name = "sospecha")
    private int sospecha;

    @Column(name = "confianza_nadia")
    private int confianzaNadia;

    @Column(name = "indicios")
    private int indicios;

    @Column(name = "fecha_guardado")
    private LocalDateTime fechaGuardado;

    // 1. Constructor vacío obligatorio por la especificación JPA
    public Partida() {
    }

    // 2. Constructor útil para iniciar una nueva partida en el Día 1
    public Partida(String nombreJugador) {
        this.nombreJugador = nombreJugador;
        this.diaActual = 1;
        this.creditos = 100; // Recursos iniciales según el guion por ahora
        this.sospecha = 0;
        this.confianzaNadia = 50;
        this.indicios = 0;
        this.fechaGuardado = LocalDateTime.now();
    }

    // --- Getters y Setters ---

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getNombreJugador() {
        return nombreJugador;
    }

    public void setNombreJugador(String nombreJugador) {
        this.nombreJugador = nombreJugador;
    }

    public int getDiaActual() {
        return diaActual;
    }

    public void setDiaActual(int diaActual) {
        this.diaActual = diaActual;
    }

    public int getCreditos() {
        return creditos;
    }

    public void setCreditos(int creditos) {
        this.creditos = creditos;
    }

    public int getSospecha() {
        return sospecha;
    }

    public void setSospecha(int sospecha) {
        this.sospecha = sospecha;
    }

    public int getConfianzaNadia() {
        return confianzaNadia;
    }

    public void setConfianzaNadia(int confianzaNadia) {
        this.confianzaNadia = confianzaNadia;
    }

    public int getIndicios() {
        return indicios;
    }

    public void setIndicios(int indicios) {
        this.indicios = indicios;
    }

    public LocalDateTime getFechaGuardado() {
        return fechaGuardado;
    }

    public void setFechaGuardado(LocalDateTime fechaGuardado) {
        this.fechaGuardado = fechaGuardado;
    }
}
